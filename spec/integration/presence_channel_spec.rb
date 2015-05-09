#encoding: utf-8

require 'spec_helper'

describe 'Integration' do
  before(:each) { start_slanger { test_setup }}

  let(:test_setup) do
    allow(Slanger::PresenceChannel::RandomSubscriptionId).to receive(:next).
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

          expect(messages).to have_attributes connection_established: true, id_present: true,
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

          expect(messages).to have_attributes connection_established: true, count: 3

          data = {"presence"=>{"count"=>1,
                               "ids"=>["0f177369a3b71275d25ab1b44db9f95f"],
                               "hash"=>{"0f177369a3b71275d25ab1b44db9f95f"=>{"name"=>"SG"}}}}

          expect(messages.last).to eq({"channel"=>"presence-channel",
                                   "event"  =>"pusher_internal:subscription_succeeded",
                                   "data"   => data.to_json})
        end




        context 'with more than one subscriber subscribed to the channel' do
          it 'sends a member added message to the existing subscribers' do
            messages  = em_stream do |user1, messages|
              Slanger.debug "SPEC messages.length: #{messages.length}"
              case messages.length
              when 1
                send_subscribe(user: user1,
                               user_id: '0f177369a3b71275d25ab1b44db9f95f',
                               name: 'SG',
                               message: messages.first
                              )

              when 2
                new_websocket.tap do |websocket|
                  websocket.stream do |message|
                    message = JSON.parse(message)

                    if message['event'] == 'pusher:connection_established'
                      send_subscribe(user: websocket,
                               user_id: '37960509766262569d504f02a0ee986d',
                               name: 'CHROME',
                               message: message
                              )
                    end
                  end
                end
              when 3
                EM.next_tick { EM.stop }
              end
            end

            expect(messages).to have_attributes connection_established: true, count: 2
            # Channel id should be in the payload
            expect(messages[1]).to eq({"channel"=>"presence-channel", "event"=>"pusher_internal:subscription_succeeded",
                                     "data"=>"{\"presence\":{\"count\":1,\"ids\":[\"0f177369a3b71275d25ab1b44db9f95f\"],\"hash\":{\"0f177369a3b71275d25ab1b44db9f95f\":{\"name\":\"SG\"}}}}"})

            expect(messages.last).to eq({"channel"=>"presence-channel", "event"=>"pusher_internal:member_added",
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
                EM.next_tick { EM.stop }
              end

            end

            # There should only be one set of presence messages sent to the reference user for the second user.
            one_added = messages.one? { |message| message['event'] == 'pusher_internal:member_added'   && message['data']['user_id'] == '37960509766262569d504f02a0ee986d' }
            expect(one_added).to be_truthy

            one_removed = messages.one? { |message| message['event'] == 'pusher_internal:member_removed' && message['data']['user_id'] == '37960509766262569d504f02a0ee986d' }
            expect(one_removed).to be_truthy
          end
        end
      end
    end
  end
end
