# PresenceChannel class.
#
# Uses an EventMachine channel to let handlers interact with the
# Pusher channel. Relay events received from Redis into the
# EM channel. Keeps data on the subscribers to send it to clients.
#

require 'eventmachine'
require 'forwardable'
require 'fiber'

module Slanger
  class PresenceChannel < Channel
    extend  Forwardable
    def_delegators :roster, :ids, :subscribers

    def initialize(channel_id)
      super channel_id

      fetch_roster
    end

    # Send an event received from Redis to the EventMachine channel
    def dispatch(message, channel_id)
      Slanger.debug "PresenceChannel dispatch message: channel_id: #{channel_id} msg: #{message}"

      if channel_id =~ /^slanger:/
        # Messages received from the Redis channel slanger:*  carry info on
        # roster. Update our subscribers accordingly.
        update_subscribers message
      else
        push message.to_json
      end
    end

    def subscribe(msg, on_subscribe_callback, &blk)
      channel_data = JSON.parse msg['data']['channel_data']
      public_subscription_id = next_random

      # Send event about the new subscription to the Redis slanger:connection_notification Channel.
      publisher = publish_connection_status_change(
        subscription_id: public_subscription_id,
        online: true,
        channel_data: channel_data,
        channel: channel_id
      )

      publisher_callback = publisher_callback_from(publisher, public_subscription_id, on_subscribe_callback, &blk)

      # Associate the subscription data to the public id in Redis.
      roster.add(public_subscription_id, channel_data, publisher_callback)

      public_subscription_id
    end

    def next_random
      SecureRandom.uuid
    end

    def publisher_callback_from(publisher, public_subscription_id, on_subscribe_callback, &blk)
      Proc.new do
        Slanger.debug "Start publisher callback #{public_subscription_id}"
        # fuuuuuuuuuccccccck!
        publisher.callback do
          Slanger.debug "Publisher callback complete"

          EM.next_tick do
            id = em_channel.subscribe &blk
            Slanger.debug "Set public_to_em_channel_table #{public_subscription_id} => #{id}"
            # Add the subscription to our table.
            public_to_em_channel_table[public_subscription_id] = id


            # The Subscription event has been sent to Redis successfully
            on_subscribe_callback.call
          end
        end
      end
    end

    def unsubscribe(public_subscription_id)
      Slanger.debug "Leaving presence channel #{public_subscription_id} - notify_all_instances"
      # Unsubcribe from EM::Channel
      em_channel.unsubscribe(public_to_em_channel_table.delete(public_subscription_id))
      # Remove subscription data from Redis
      roster.remove public_subscription_id
      # Notify all instances
      publish_connection_status_change subscription_id: public_subscription_id,
        online: false, channel: channel_id
    end

    private

    def roster
      @roster ||= Roster.new channel_id
    end

    def fetch_roster
      roster.fetch
    end

    def publish_connection_status_change(payload, retry_count=0)
      Slanger.debug "#{__method__}(#{payload}, #{retry_count})"

      # Send a subscription notification to the global slanger:connection_notification
      # channel.
      Slanger::Redis.
        publish('slanger:connection_notification', payload.to_json).
        callback{
          Slanger.debug "#{__method__} complete (#{payload}, #{retry_count})"
        }.
        errback {
          if retry_count != 5
            publish_connection_status_change payload, retry_count.succ 
          else
            Slanger.debug "Retries failed, not publishing slanger:connection_notification(#{payload}, #{retry_count})"
          end
        }
    end


    # This is used map public subscription ids to em channel subscription ids.
    # em channel subscription ids are incremented integers, so they cannot
    # be used as keys in distributed system because they will not be unique
    def public_to_em_channel_table
      @public_to_em_channel_table ||= {}
    end

    def update_subscribers(message)
      Slanger.debug "incoming message #{__method__} #{message}"

      if message['online']
        member = message['channel_data']
        roster[message['subscription_id']] = member
        # Don't tell the channel subscribters a new member has been added if the subscriber data
        # is already present in the roster hash, e.g. multiple browser windows open.
        unless roster.present?(member)
          push payload('pusher_internal:member_added', member)
        end
      else
        # Don't tell the channel subscriptions the member has been removed if the subscriber data
        # still remains in the roster hash, e.g. multiple browser windows open.
        subscriber = roster.delete message['subscription_id']
        if subscriber && !roster.has_value?(subscriber)
          push payload('pusher_internal:member_removed', { user_id: subscriber['user_id'] })
        end
      end
    end

    def payload(event_name, payload = {})
      { channel: channel_id, event: event_name, data: payload }.to_json
    end
  end
end
