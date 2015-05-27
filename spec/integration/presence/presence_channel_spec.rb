#encoding: utf-8

require 'spec_helper'

describe 'Integration' do
  before(:each) { start_slanger { set_predictable_socket_and_subscription_ids! }}

  describe 'presence channels:' do
    context 'subscribing without channel data' do
      context 'and bogus authentication credentials' do
        it 'sends back an error message' do
          messages  = em_stream do |websocket, messages|
            case messages.length
            when 1
              websocket.send({ event: 'pusher:subscribe', data: { channel: 'presence-channel', auth: 'bogus' } }.to_json)
            when 2
              EM.next_tick { EM.stop }
            end
          end

          expect(messages).to have_attributes \
            connection_established: true,
            id_present: true,
            count: 2,
            last_event: 'pusher:error'

          expect(JSON.parse(messages.last['data'])['message']).to match /^Invalid signature: Expected HMAC SHA256 hex digest of/
        end
      end
    end

    context 'subscribing with channel data' do
      context 'and bogus authentication credentials' do
        it 'sends back an error message' do
          messages  = em_stream do |websocket, messages|
            case messages.length
            when 1
              websocket.send({ event: 'pusher:subscribe', data: {
                channel: 'presence-lel',
                auth: 'boog',
                channel_data: {
                  user_id: "barry",
                }
              }.to_json }.to_json)
           else
              EM.next_tick { EM.stop }
            end
          end

          expect(messages).to have_attributes first_event: 'pusher:connection_established', count: 2,
            id_present: true

          # Channel id should be in the payload
          expect(messages.last['event']).to eq('pusher:error')
          expect(JSON.parse(messages.last['data'])['message']).to match /^Invalid signature: Expected HMAC SHA256 hex digest of/
        end
      end

      context 'with genuine authentication credentials'  do
        it 'sends back a success message' do
          messages  = em_stream do |websocket, messages|
            case messages.length
            when 1
              send_subscribe( user: websocket,
                              user_id: '0f177369a3b71275d25ab1b44db9f95f',
                              name: 'SG',
                              message: messages.first)
            when 2
              EM.stop
            end
          end

          expect(messages).to have_attributes connection_established: true, count: 2

          data = {"presence"=>{"count"=>1,
                               "ids"=>["0f177369a3b71275d25ab1b44db9f95f"],
                               "hash"=>{"0f177369a3b71275d25ab1b44db9f95f"=>{"name"=>"SG"}}}}

          expect(messages.last).to eq({"channel"=>"presence-channel",
                                   "event"  =>"pusher_internal:subscription_succeeded",
                                   "data"   => data.to_json})
        end

        context 'with more than one subscriber subscribed to the channel' do
          it 'sends a member added message to the existing subscribers' do
            client1_messages, client2_messages  = [], []

            em(0.5) do
              client1, client2 = new_websocket, new_websocket
              client2_messages, client1_messages = [], []

              timer_added = false
              stream(client1, client1_messages, "Client 1") do |message|
                Slanger.error "client1_messages.length #{client1_messages.length}"
                case client1_messages.length
                when 1
                  send_subscribe(user: client1,
                                 user_id: '0f177369a3b71275d25ab1b44db9f95f',
                                 name: 'SG',
                                 message: client1_messages.first
                                )
                else
                  unless timer_added
                    EventMachine::PeriodicTimer.new(0.01) do
                      timer_added=true

                      if client2_messages.length >= 2
                        EM.stop
                      end
                    end
                  end
                end
              end

              stream(client2, client2_messages, "Client 2") do
                Slanger.error "client2_messages: #{client2_messages}"
                Slanger.error "client2_messages.length #{client2_messages.length}"

                unless @sent_subscribe
                  timer = EventMachine::PeriodicTimer.new(0.01) do
                    message = client1_messages.find{|m| m["event"] == "pusher_internal:subscription_succeeded" }

                    if message && !@sent
                      @sent = true
                      send_subscribe(
                        user: client2,
                        user_id: '37960509766262569d504f02a0ee986d',
                        name: 'CHROME',
                        message: client2_messages.first
                      )
                      Slanger.error "SPEC sent subscribe"
                      timer.cancel
                    end
                  end
                  @sent_subscribe = true
                end
              end
            end

            expect(client1_messages).to have_attributes connection_established: true
            # Channel id should be in the payload
            #data = {presence: {"count"=>2, "ids"=>["0f177369a3b71275d25ab1b44db9f95f", "37960509766262569d504f02a0ee986d"], "hash"=>{"0f177369a3b71275d25ab1b44db9f95f"=>{"name"=>"SG"}, "37960509766262569d504f02a0ee986d"=>{"name"=>"CHROME"}}}}
            data = {presence: {"count"=>1, "ids"=>["0f177369a3b71275d25ab1b44db9f95f"], "hash"=>{"0f177369a3b71275d25ab1b44db9f95f"=>{"name"=>"SG"}}}}

            subscription_message = client1_messages.find{|m| m["event"] == "pusher_internal:subscription_succeeded"}
            expect(subscription_message).to eq({"channel"=>"presence-channel", "event"=>"pusher_internal:subscription_succeeded",
                                               "data"=>data.to_json})

            added_message = client1_messages.find{|m| m["event"] == "pusher_internal:member_added" && m["data"]["user_id"] == "37960509766262569d504f02a0ee986d"}
            expect(added_message).to eq({"channel"=>"presence-channel", "event"=>"pusher_internal:member_added",
                                               "data"=>{"user_id"=>"37960509766262569d504f02a0ee986d", "user_info"=>{"name"=>"CHROME"}}})
          end


          it 'does not send multiple member added and member removed messages if one subscriber opens multiple connections, i.e. multiple browser tabs.' do
            messages = em_stream do |user1, messages|
              case messages.length
              when 1
                subscribe_to_presence_channel(user1, {user_id: "0f177369a3b71275d25ab1b44db9f95f", name: "SG"}, "1.1")
              when 2
                multiple_async_connections(3) do |ws, socket_id|
                  subscribe_to_presence_channel(ws, {user_id: "37960509766262569d504f02a0ee986d", name: "CHROME"}, socket_id)
                end
              when 6 #(ws_1 connection, subscription), 3 (connection + subscription), 3 disconnect
                EM.stop
              end
            end

            # There should only be one set of presence messages sent to the reference user for the second user.
            added = messages.select {|m| m['event'] == 'pusher_internal:member_added' && m['data']['user_id'] == '37960509766262569d504f02a0ee986d' }
            expect(added.length).to eq 1
          end
        end
      end

      def multiple_async_connections(num)
        multiple_sockets(num) do |u, msg, i|
          msg = JSON.parse msg
          socket_id = msg.to_s[/\d\.\d/]

          if msg["event"]=="pusher:connection_established"  
            if JSON.parse(msg["data"])["socket_id"] == socket_id
              EM.add_timer(0.1 + (0.5 * i.to_f * rand)) do
                yield u, socket_id

                EM.add_timer(0.5 + (0.5 * i.to_f * rand)) do
                  u.close_connection
                end
              end
            end
          end
        end
      end

      def multiple_sockets(num)
        num.times.map do |i|
          new_websocket.tap do |u|
            u.stream do |msg|
              yield u, msg, i
            end
          end
        end
      end
    end
  end
end
