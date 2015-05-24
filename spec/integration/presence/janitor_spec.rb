require "spec_helper"

describe "Janitor" do
  after do
    stop_ha_proxy
  end

  before do
    start_slanger_nodes_and_haproxy
  end

  describe Slanger::WebSocketServer do
    it "responds to a roll-call-request message"do
      responses = run_roll_call!

      expect(responses.length). to eq 2
      a,b = responses
      expect([a["node_id"], b["node_id"]]).to contain_exactly 1,2
      expect(a["pid"]).to be > 0
      expect(b["pid"]).to be > 0
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
        dead_node_id = "123456789"
        redis.sadd "slanger-roster-presence-channel-node-#{dead_node_id}", {user_id: "not here"}
      end

      it "sanity check" do
        expect(Slanger::Service.present_node_ids).to eq ["1", "2"]
      end

      it "updates the present node ids in redis" do
        messages = run_roll_call!
        expect(messages.length). to eq 2

        expect(redis.smembers("slanger-online-node-ids")).to contain_exactly "1", "2"
      end

      it "removes invalid existing presence channel info" do
        expect(redis_keys).to  include "slanger-roster-presence-channel-node-123456789"

        setup_test {|stopped|
          EM.add_timer 5 do
            expect(redis_keys).not_to  include "slanger-roster-presence-channel-node-123456789"

            EM.stop
          end
        }

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
        setup_test(auto_stop: nil) do |stopped|
          if stopped
            Slanger.error "expecting 1,2"
            expect(Slanger::Service.present_node_ids).to contain_exactly "1", "2"
          else
              Slanger.error "expecting 1,3"
            EM.add_timer 4 do
              Slanger.error "expecting 1,3"
              #we can't guarantee the order of the pids in our server_pids variable
              #so sometimes node 1 is stopped other times node 2
              expect(Slanger::Service.present_node_ids).to include "3"
              expect(Slanger::Service.present_node_ids.length).to eq 2
              EM.stop
            end
          end
        end
      end
    end
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

  def setup_test(auto_stop: 2)
    #sanity check
    expect(Slanger::Service.present_node_ids).to contain_exactly "1", "2"

    first_run = true
    EM.run do
      if first_run
        first_run=false
        Slanger::Janitor.run(1)
        setup_websocket_connections

        #allow async redis updates to happen
        EM.add_timer 2 do
          #sanity check
          expect(redis.hgetall "slanger-roster-presence-channel-node-1").to eq({"S1-1"=>"0f177369a3b71275d25ab1b44db9f95f"})
          expect(redis.hgetall "slanger-roster-presence-channel-node-2").to eq({"S2-1"=>"0f177369a3b71275d25ab1b44db9f95f"})

          stop_slanger [server_pids[1]]

          yield stopped=true if block_given?

          start_slanger(websocket_port: 8082, api_port: 4569) { set_predictable_socket_and_subscription_ids! }
          wait_for_socket(8082)

          yield stopped=false if block_given?
        end


        if auto_stop
          Slanger::Janitor.subscribe_to_roll_call do |msg|
            if Slanger::Janitor.acknowledgements.length == auto_stop
              EM.stop
            end
          end
        end
      end
    end
  end

  def setup_websocket_connections
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
  end



end
# node-1 offline case
# keys slanger-roster-presence-*-node-1 each do |key|
#   hdel "slanger-internal-presence-abcd-#{key}", "node-1"
#
