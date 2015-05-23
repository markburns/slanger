require "spec_helper"

describe "Janitor" do
  after do
    stop_ha_proxy
  end

  before do
    start_slanger_nodes_and_haproxy
  end

  def run_roll_call!(expected_message_count: 2, stop_on_message_count_reached: true)
    messages = []
    first_run=true

    EM.run do
      if first_run
        Slanger::Janitor.setup! 2

        Slanger::Janitor.subscribe_to_roll_call do |msg|
          messages << msg if msg["type"]=="response"

          if messages.length == expected_message_count && stop_on_message_count_reached
            EM.stop
          end
        end

        first_run = false
        Slanger::Janitor.request!
      end
    end

    messages
  end

  describe Slanger::WebSocketServer do
    it "responds to a roll-call-request message"do
      messages = run_roll_call!

      expect(messages.length). to eq 2
      a,b = messages
      expect([a["node_id"], b["node_id"]]).to contain_exactly 1,2
      expect(a["pid"]).to be > 0
      expect(b["pid"]).to be > 0
    end
  end

  def setup_test
    #sanity check
    expect(Slanger::Service.present_node_ids).to contain_exactly "1", "2"

    first_run = true
    EM.run do
      if first_run
        ws_1_messages = []
        ws_2_messages = []

        ws_1 = nil
        ws_2 = nil
        user = {user_id: "0f177369a3b71275d25ab1b44db9f95f", name: "SG"}

        #subscribe to one node
        new_ws_stream(ws_1_messages, "ws_1") do |ws, message|
          ws_1 ||= ws

          if ws_1_messages.length == 1
            #socket_id depends on which node is hit first
            socket_id = ws_1_messages.first["data"][/\d.\d/]
            subscribe_to_presence_channel( ws_1, user, socket_id)
          end
        end

        #subscribe to other node
        new_ws_stream(ws_2_messages, "ws_2") do |ws, message|
          ws_2 ||= ws

          if ws_2_messages.length == 1
            socket_id = ws_2_messages.first["data"][/\d.\d/]
            subscribe_to_presence_channel( ws_2, user, socket_id)
          end
        end

        #allow async redis updates to happen
        EM.add_periodic_timer 1 do
          unless @restarted
            #restart one node after both subscriptions complete
            expect(redis.hgetall "slanger-roster-presence-channel-node-1").to eq({"S1-1"=>"0f177369a3b71275d25ab1b44db9f95f"})
            expect(redis.hgetall "slanger-roster-presence-channel-node-2").to eq({"S2-1"=>"0f177369a3b71275d25ab1b44db9f95f"})

            stop_slanger [server_pids[1]]
            yield if block_given?

            start_slanger(websocket_port: 8082, api_port: 4569) { set_predictable_socket_and_subscription_ids! }
            wait_for_socket(8082)

            @restarted = true
          end
        end
      end

      first_run=false

      EM.add_periodic_timer 2 do
        puts "cheese: @restarted:#{@restarted}"
        puts "cheese: ws_2_messages:#{ws_2_messages.length}"
        #expect(redis_keys).to eq []

        if @restarted
          Slanger::Janitor.em_channel.subscribe do |msg|
            expect(msg[:type]).to eq "update"
            EM.stop
          end

          run_roll_call!(expected_message_count: 1, stop_on_message_count_reached: false)
        end
      end

    end
  end

  describe Slanger::Janitor do
    def redis
      Slanger::Redis.sync_redis_connection
    end

    def redis_keys
      redis.keys
    end

    context "coming online in an incorrect state" do
      before do
        dead_node_id = "shouldnt-exist"
        redis.sadd "slanger-roster-presence-channel-node-#{dead_node_id}", {user_id: "not here"}
      end

      it "sanity check" do
        expect(Slanger::Service.present_node_ids).to eq ["1", "2"]
      end

      it "updates the present node ids in redis" do
        messages = run_roll_call!
        expect(messages.length). to eq 2

        expect(redis.smembers("slanger-online-node-ids")).to contain_exactly 1, 2
      end

      it "removes invalid existing presence channel info" do
        expect(redis_keys).to  include "slanger-roster-presence-channel-node-shouldnt-exist"

        setup_test { 
        expect(redis_keys).not_to  include "slanger-roster-presence-channel-node-shouldnt-exist"

          EM.stop 
        }

        Slanger::Janitor.clear_invalid_keys!
      end
    end

    # request online nodes
    #
    # waits
    #
    # collate node id responses
    # delete any existing presence channel info from non-responding nodes
    #
    # maintain a list of present nodes
    # notify other nodes of which nodes are online
    #
    # slanger nodes respond to online node notifications by removing non-present from internal rosters
    # slanger nodes respond to offline node notifications by those from internal rosters
    context "after stopping a node" do
      it "removes stopped nodes" do
        setup_test do
          expect(Slanger::Service.present_node_ids).to contain_exactly "1", "2"
        end

        expect(Slanger::Service.present_node_ids).to contain_exactly "1", "3"
      end

      it "removes invalid keys" do
        setup_test {}

        keys = ["channel_subscriber_count", "slanger-node", "slanger-online-node-ids", "slanger-roster-presence-channel", "slanger-roster-presence-channel-node-2"]
        expect(redis_keys).to contain_exactly *keys
      end
    end
  end
end
# node-1 offline case
# keys slanger-roster-presence-*-node-1 each do |key|
#   hdel "slanger-internal-presence-abcd-#{key}", "node-1"
#
