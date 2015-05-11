#encoding: utf-8

require 'spec_helper'
require "fiber"

describe "PresenceChannel Roster" do

  context "with multiple instances of channel connections to the same PresenceChannel (i.e. multiple nodes)" do
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
      start_slanger(websocket_port: 8081, api_port: 4568, &socket_id_block(1, 3))
      start_slanger(websocket_port: 8082, api_port: 4569, &socket_id_block(2, 4))

      start_ha_proxy
      wait_for_socket(8080)
      wait_for_socket(4567)
    end

    def socket_id_block(*ids)
      Proc.new do
        expect(Slanger::Connection::RandomSocketId).
          to receive(:next).
          and_return(*ids.map{|id| "random-socket-id-#{id}"})

        allow(Slanger).to receive(:node_id).and_return(*ids)
      end
    end

    it do
      roster_1 = Slanger::Presence::Roster.new "presence-channel"

      em_thread do
        ws_1 = new_websocket

        user = {user: ws_1, user_id: '0f177369a3b71275d25ab1b44db9f95f', name: 'MB'}
        subscribe_to_presence_channel(ws_1, user, "random-socket-id-1")

        ws_2 = new_websocket
        subscribe_to_presence_channel(ws_2, user, "random-socket-id-2")


        EM.add_timer(0.5) do
          Slanger.error "SPEC after fetch"
          user_1 = {"user_id" => "0f177369a3b71275d25ab1b44db9f95f", "user_info" => {}}

          expected = {
            user_1 => {
              "node:1" => ["subscription:abc"],
              "node:2" => ["subscription:def"]
            }
          }

          expect(roster_1.internal_roster).to eq expected

          EM.stop
        end
      end
    end
  end
end
