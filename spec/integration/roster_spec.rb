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
      test_setup_1 = socket_id_block(roster_index=0, node_id="1", subscription_ids=["S1", "S3"], socket_ids = ["1.1", "1.2"])
      test_setup_2 = socket_id_block(roster_index=1, node_id="2", subscription_ids=["S2", "S4"], socket_ids = ["2.1", "2.2"])

      start_slanger(websocket_port: 8081, api_port: 4568, &test_setup_1)
      start_slanger(websocket_port: 8082, api_port: 4569, &test_setup_2)

      start_ha_proxy
      wait_for_socket(8080)
      wait_for_socket(4567)
    end

    def socket_id_block(roster_index, node_id, subscription_ids, socket_ids)
      Proc.new do
        expect(Slanger::Connection::RandomSocketId).
          to receive(:next).
          and_return(*socket_ids)

        expect(Slanger::Channel::RandomSubscriptionId).
          to receive(:next).
          and_return(*subscription_ids)


        allow(Slanger).to receive(:node_id).and_return(node_id)
      end
    end

    it "updates the internal rosters correctly for each node" do
      messages_1, messages_2 = [], []
      ws_1 = nil
      ws_2 = nil

      user = {user_id: '0f177369a3b71275d25ab1b44db9f95f', user_info: {name: 'MB'}}

      # Timeline representation
      # ws_1 connect (node 1)                  ws_2 connect (node 2)
      # |                                      |
      # v                                      v
      # connection_established                 |
      # |                                      subscribe to presence
      # v                                      socket 2.1
      # subscribe to presence_channel          |
      # socket 1.1                             |
      # |                                      |
      # v                                      presence acknowledgement
      # presence acknowledgement               |
      # |                                      |
      # check roster state                     v
      # |                                      |
      # |                                      close ws_2
      # |
      # check roster state
      #
      #
      em_thread do
        ws_1 = new_websocket

        stream(ws_1, messages_1, "ws_1") do |message|
          case messages_1.length
          when 1
            unless @subscribed_ws_1
              subscribe_to_presence_channel(ws_1, user, "1.1")
              @subscribed_ws_1 = true

              EM.add_periodic_timer(0.8) do
                if @subscribed_ws_2 && !@closing_ws_2 && !@closed_ws_2
                  #we can't check the roster status after EM.stop as it
                  #closes the websockets and removes the members
                  expect(Slanger::Presence::Roster.new("presence-channel").internal_roster).to eq({
                    "1" =>{"S1" => user[:user_id]},
                    "2" =>{"S2" => user[:user_id]}
                  })

                  Slanger.error "unbinding ws_2"
                  ws_2.close_connection
                  @closing_ws_2 = true
                  #give socket time to close
                  EM.add_timer 0.5 do
                    Slanger.error "timer closed_ws_2"
                    @closed_ws_2 = true
                  end
                end
              end
            end
          end
        end

        ws_2 = new_websocket

        stream(ws_2, messages_2, "ws_2") do |message|
          unless @subscribed_ws_2
            EM.add_periodic_timer(0.3) do
              unless @subscribed_ws_2
                if messages_1.length >= 1 && messages_2.length >= 1
                  @subscribed_ws_2 = true
                  subscribe_to_presence_channel(ws_2, user, "2.1")
                end
              end
            end
          end
        end

        EM.add_periodic_timer(0.3) do
          if @closed_ws_2
            Slanger.error "periodic timer closed_ws_2"
            expect(Slanger::Presence::Roster.new("presence-channel").internal_roster).to eq({
              "1" =>{"S1" => user[:user_id]}
            })

            EM.stop
          end
        end
      end
    end
  end
end
