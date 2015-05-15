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

  describe Slanger::WebSocketServer do
    it "responds to a roll-call-request message"do
      messages = []

      EM.run do
        unless @first_run
          @first_run = true
          Slanger::Janitor.register_roll_call! do |msg|
            Slanger.error "SPEC Message received #{msg}"
            messages << JSON.parse(msg)

            if messages.length == 2
              EM.stop
            end
          end

          Slanger::Janitor.request 
        end
      end
      expect(messages.length). to eq 2
      a,b = messages
      expect(a["node_id"]).to eq 1
      expect(b["node_id"]).to eq 2
      expect(a["pid"]).to be > 0
      expect(b["pid"]).to be > 0
    end
  end
end
# node-1 offline case
# keys slanger-roster-presence-*-node-1 each do |key|
#   hdel "slanger-internal-presence-abcd-#{key}", "node-1"
#
