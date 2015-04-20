# PresenceChannel class.
#
# Uses an EventMachine channel to let handlers interact with the
# Pusher channel. Relay events received from Redis into the
# EM channel. Keeps data on the subscribers to send it to clients.
#

require 'glamazon'
require 'eventmachine'
require 'forwardable'
require 'fiber'

module Slanger
  class PresenceChannel < Channel
    # Send an event received from Redis to the EventMachine channel
    def dispatch(message, channel_id)
      Slanger.debug "PresenceChannel dispatch message: channel_id: #{channel_id} msg: #{message}"

      if channel_id =~ /^slanger:/
        # Messages received from the Redis channel slanger:*  carry info on
        # subscriptions. Update our subscribers accordingly.
        update_subscribers message
      else
        push message.to_json
      end
    end

    def subscribe(msg, on_subscribe_callback, &blk)
      channel_data = JSON.parse msg['data']['channel_data']
      public_subscription_id = SecureRandom.uuid

      # Send event about the new subscription to the Redis slanger:connection_notification Channel.
      #
      publisher = publish_connection_status_change(
        subscription_id: public_subscription_id,
        online: true,
        channel_data: channel_data,
        channel: channel_id
      )

      publisher_callback = publisher_callback_from(publisher, public_subscription_id, on_subscribe_callback, &blk)

      # Associate the subscription data to the public id in Redis.
      roster_add(public_subscription_id, channel_data, publisher_callback)

      public_subscription_id
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

    def ids
      subscribers.map(&:first)
    end

    def subscribers
      Hash[subscriptions.map { |_,v| [v['user_id'], v['user_info']] }]
    end

    def unsubscribe(public_subscription_id)
      Slanger.debug "Leaving presence channel - notify_all_instances"
      # Unsubcribe from EM::Channel
      em_channel.unsubscribe(public_to_em_channel_table.delete(public_subscription_id))
      # Remove subscription data from Redis
      roster_remove public_subscription_id
      # Notify all instances
      publish_connection_status_change subscription_id: public_subscription_id, online: false, channel: channel_id
    end

    private

    # This is the state of the presence channel across the system. kept in sync
    # with redis pubsub
    def subscriptions
      @subscriptions ||= get_roster || {}
    end

    def get_roster
      # Read subscription infos from Redis.
      Fiber.new do
        f = Fiber.current
        Slanger::Redis.hgetall(channel_id).
          callback { |res| f.resume res }
        Fiber.yield
      end.resume
    end

    def roster_add(key, value, on_add_callback)
      # Add subscription info to Redis.
      Slanger::Redis.hset(channel_id, key, value).callback{on_add_callback.call}
    end

    def roster_remove(key)
      # Remove subscription info from Redis.
      Slanger::Redis.hdel(channel_id, key)
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
      if message['online']
        # Don't tell the channel subscriptions a new member has been added if the subscriber data
        # is already present in the subscriptions hash, i.e. multiple browser windows open.
        unless subscriptions.has_value? message['channel_data']
          push payload('pusher_internal:member_added', message['channel_data'])
        end
        subscriptions[message['subscription_id']] = message['channel_data']
      else
        # Don't tell the channel subscriptions the member has been removed if the subscriber data
        # still remains in the subscriptions hash, i.e. multiple browser windows open.
        subscriber = subscriptions.delete message['subscription_id']
        if subscriber && !subscriptions.has_value?(subscriber)
          push payload('pusher_internal:member_removed', { user_id: subscriber['user_id'] })
        end
      end
    end

    def payload(event_name, payload = {})
      { channel: channel_id, event: event_name, data: payload }.to_json
    end
  end
end
