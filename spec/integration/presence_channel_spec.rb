#encoding: utf-8

require 'spec_helper'

describe 'Integration' do
  before(:each) { start_slanger { test_setup }}

  let(:test_setup) do
    allow(Slanger::Presence::Channel::RandomSubscriptionId).to receive(:next).
      and_return(*ids("subscription"))

    allow(Slanger::Connection::RandomSocketId).to receive(:next).
      and_return(*ids("socket"))
  end

  def ids(name, count=29)
    (1..count).to_a.map{|i| "#{name}-#{i}"}
  end

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

            em_thread do
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

                      if client2_messages.length == 2
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

            expect(client1_messages).to have_attributes connection_established: true, count: 2
            # Channel id should be in the payload
            #data = {presence: {"count"=>2, "ids"=>["0f177369a3b71275d25ab1b44db9f95f", "37960509766262569d504f02a0ee986d"], "hash"=>{"0f177369a3b71275d25ab1b44db9f95f"=>{"name"=>"SG"}, "37960509766262569d504f02a0ee986d"=>{"name"=>"CHROME"}}}}
            data = {presence: {"count"=>1, "ids"=>["0f177369a3b71275d25ab1b44db9f95f"], "hash"=>{"0f177369a3b71275d25ab1b44db9f95f"=>{"name"=>"SG"}}}}

            expect(client1_messages[1]).to eq({"channel"=>"presence-channel", "event"=>"pusher_internal:subscription_succeeded",
                                               "data"=>data.to_json})

            expect(client1_messages[0]).to eq({"channel"=>"presence-channel", "event"=>"pusher_internal:member_added",
                                               "data"=>{"user_id"=>"37960509766262569d504f02a0ee986d", "user_info"=>{"name"=>"CHROME"}}})
          end

          it 'does not send multiple member added and member removed messages if one subscriber opens multiple connections, i.e. multiple browser tabs.' do
            messages  = em_stream do |user1, messages|
              case messages.length
              when 1
                send_subscribe(user: user1,
                               user_id: '0f177369a3b71275d25ab1b44db9f95f',
                               name: 'SG',
                               message: messages.first)

              when 2
                3.times do
                  new_websocket.tap do |u|
                    u.stream do |message|
                      send_subscribe({ user: u,
                                       user_id: '37960509766262569d504f02a0ee986d',
                                       name: 'CHROME',
                                       message: JSON.parse(message)})
                    end
                  end
                end
              when 3
                EM.next_tick { EM.stop }
              end

            end

            # There should only be one set of presence messages sent to the reference user for the second user.
            added   = messages.select {|m| m['event'] == 'pusher_internal:member_added'   && m['data']['user_id'] == '37960509766262569d504f02a0ee986d' }
            removed = messages.select {|m| m['event'] == 'pusher_internal:member_removed' && m['data']['user_id'] == '37960509766262569d504f02a0ee986d' }
            expect(added.length).to eq 1
            expect(removed.length).to eq 1
          end
        end
      end
    end
  end
end
