require "spec_helper"

describe "Janitor" do
  def start_ha_proxy
    Slanger.debug "Starting haproxy"

    fork_reactor do
      exec "haproxy -f spec/support/haproxy.cfg"
    end
  end

  after do
    `killall -9 haproxy`
  end

  before do
    `killall -9 haproxy`
    start_slanger(websocket_port: 8081, api_port: 4568) { set_predictable_socket_and_subscription_ids! }
    start_slanger(websocket_port: 8082, api_port: 4569) { set_predictable_socket_and_subscription_ids! }
    wait_for_socket(8081)
    wait_for_socket(8082)

    start_ha_proxy
    wait_for_socket(8080)
    wait_for_socket(4567)
  end

  def run_roll_call!(expected_message_count: 2, stop_on_message_count_reached: true)
    messages = []
    first_run=true

    EM.run do
      Slanger::Janitor.register_roll_call!(silent_listener: true) do |msg|
        messages << msg unless msg["type"]=="request"

        if messages.length == expected_message_count && stop_on_message_count_reached
          EM.stop
        end
      end

      Slanger::Janitor.request!
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

  describe Slanger::Janitor do
    it "updates the present node ids in redis" do
      messages = run_roll_call!
      expect(messages.length). to eq 2

      expect(Slanger::Service.present_node_ids).to contain_exactly "1", "2"
    end

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


      def redis
        Slanger::Redis.sync_redis_connection
      end

      def redis_keys
        redis.keys
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

            new_ws_stream(ws_1_messages, "ws_1") do |ws, message|
              ws_1 ||= ws
              if ws_1_messages.length == 1
                #socket_id depends on which node is hit first
                socket_id = ws_1_messages.first["data"][/\d.\d/]
                subscribe_to_presence_channel( ws_1, user, socket_id)
              end
            end

            new_ws_stream(ws_2_messages, "ws_2") do |ws, message|
              ws_2 ||= ws
              if ws_2_messages.length == 1
                socket_id = ws_2_messages.first["data"][/\d.\d/]
                subscribe_to_presence_channel( ws_2, user, socket_id)
              end

              if ws_2_messages.length == 2
                #allow async redis updates to happen
                EM.add_timer 0.2 do
                  Slanger.error "SPEC - second subscription completed"
                  unless @restarted
                    #restart one node after both subscriptions complete
                    expect(redis.hgetall "slanger-roster-presence-channel-node-1").to eq({"S1-1"=>"0f177369a3b71275d25ab1b44db9f95f"})
                    expect(redis.hgetall "slanger-roster-presence-channel-node-2").to eq({"S2-1"=>"0f177369a3b71275d25ab1b44db9f95f"})

                    stop_slanger [server_pids[1]]
                    yield

                    start_slanger(websocket_port: 8082, api_port: 4569) { set_predictable_socket_and_subscription_ids! }
                    wait_for_socket(8082)

                    @restarted = true
                  end
                end
              end
            end

            first_run=false

            EM.add_periodic_timer 1 do
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
      end
    end
  end
end
# node-1 offline case
# keys slanger-roster-presence-*-node-1 each do |key|
#   hdel "slanger-internal-presence-abcd-#{key}", "node-1"
#
