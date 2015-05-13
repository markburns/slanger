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
      `killall -9 haproxy`
      test_setup_1 = socket_id_block(roster_index=0, node_id=1, socket_ids=1, 3)
      test_setup_2 = socket_id_block(roster_index=1, node_id=2, socket_ids=2, 4)

      start_slanger(websocket_port: 8081, api_port: 4568, &test_setup_1)
      start_slanger(websocket_port: 8082, api_port: 4569, &test_setup_2)

      start_ha_proxy
      wait_for_socket(8080)
      wait_for_socket(4567)
    end

    def socket_id_block(roster_index, node_id, *socket_ids)
      @unique_rosters ||= [
        Slanger::Presence::Roster.new("presence-channel"),
        Slanger::Presence::Roster.new("presence-channel")
      ]

      Proc.new do
        expect(Slanger::Connection::RandomSocketId).
          to receive(:next).
          and_return(*socket_ids.map{|id| "socket-#{id}"})

        allow(Slanger).to receive(:node_id).and_return(node_id)
        allow(Slanger::Presence::Roster).to receive(:new).and_return(@unique_rosters[roster_index])
      end
    end

    it "updates the internal rosters correctly for each node" do
      messages_1, messages_2 = [], []
      ws_1 = nil
      ws_2 = nil

      user = {user_id: '0f177369a3b71275d25ab1b44db9f95f', name: 'MB'}

      em_thread do
        ws_1 = new_websocket

        stream(ws_1, messages_1) do |message|
          case messages_1.length
          when 1
            subscribe_to_presence_channel(ws_1, user, "socket-1")
          when 2
            EM.add_periodic_timer(0.3) do
              if messages_2.length == 2
                expect(@unique_rosters[0].internal_roster).to eq({})
                expect(@unique_rosters[1].internal_roster).to eq({})


                EM.stop
              end
            end
          end
        end

        ws_2 = new_websocket

        stream(ws_2, messages_2) do |message|
          case messages_2.length
          when 1
            subscribe_to_presence_channel(ws_2, user, "socket-2")
          end
        end
      end

    end
  end
end
