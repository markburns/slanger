module Slanger
  module PresenceChannelJoining
    def join(msg, callback)
      channel_data = JSON.parse msg['data']['channel_data']
      public_subscription_id = RandomSubscriptionId.next

      # Send event about the new subscription to the Redis slanger:connection_notification Channel.
      status_change = publish_connection_status_change(
        subscription_id: public_subscription_id,
        online: true,
        channel_data: channel_data,
        channel: channel_id
      )

      online_callback = online_callback_from(status_change, public_subscription_id) do 
        callback.call 
      end

      # Associate the subscription data to the public id in Redis.
      roster.add(public_subscription_id, channel_data, online_callback)

      public_subscription_id
    end

    module RandomSubscriptionId
      def self.next
        SecureRandom.uuid
      end
    end

    def online_callback_from(status_change_redis, public_subscription_id)
      Proc.new do
        EM.next_tick do
          # fuuuuuuuuuccccccck!
          status_change_redis.callback do |*result|
            Slanger.debug "Redis online slanger:connection_notification complete, public_subscription_id: #{public_subscription_id} result: #{result}"

            id = em_channel.subscribe ->(*a){}
            yield id

            Slanger.debug "PresenceChannel joined em_channel: #{id} public_subscription_id: #{public_subscription_id}"

            public_to_em_channel_table[public_subscription_id] = id
          end
        end
      end
    end

    def summary_info
      {presence: {
        count: subscribers.size,
        ids:   ids,
        hash:  subscribers
      }}
    end
  end
end
