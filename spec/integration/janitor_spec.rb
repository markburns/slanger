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
    start_slanger(websocket_port: 8081, api_port: 4568)
    start_slanger(websocket_port: 8082, api_port: 4569)

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

    it "removes stopped nodes" do
      messages = run_roll_call!(expected_message_count: 2)
      expect(messages.length). to eq 2

      stop_slanger [server_pids[1]]

      expect(Slanger::Service.present_node_ids).to contain_exactly "1", "2"

      first_run = true
      EM.run do
        if first_run
          first_run=false
          Slanger::Janitor.em_channel.subscribe do |msg|
            expect(msg[:type]).to eq "update"
            EM.stop
          end

          run_roll_call!(expected_message_count: 1, stop_on_message_count_reached: false)
        end
      end

      expect(Slanger::Service.present_node_ids).to contain_exactly "1"
    end
  end

end
# node-1 offline case
# keys slanger-roster-presence-*-node-1 each do |key|
#   hdel "slanger-internal-presence-abcd-#{key}", "node-1"
#
