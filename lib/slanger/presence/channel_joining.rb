module Slanger
  module Presence
    module ChannelJoining
      def join(msg, &blk)
        Slanger.debug "Joining channel #{msg}"
        member = JSON.parse msg['data']['channel_data']
        public_subscription_id = RandomSubscriptionId.next

        # Send event about the new subscription to the Redis slanger:connection_notification Channel.
        status_change = update_slanger_nodes_about_presence_change(
          subscription_id: public_subscription_id,
          online: true,
          channel_data: member,
          channel: channel_id
        )

        online_callback = online_callback_from(status_change, public_subscription_id, &blk)

        # Associate the subscription data to the public id in Redis.
        roster.add(Slanger::Service.node_id, public_subscription_id, member, online_callback) do |added|
          if added
            push payload('pusher_internal:member_added', member)
          end
        end

        public_subscription_id
      end

      module RandomSubscriptionId
        def self.next
          SecureRandom.uuid
        end
      end

      def online_callback_from(status_change_redis, public_subscription_id, &blk)
        Proc.new do
          EM.next_tick do
            # fuuuuuuuuuccccccck!
            status_change_redis.callback do |*result|
              Slanger.debug "Redis online slanger:connection_notification complete, public_subscription_id: #{public_subscription_id} result: #{result}"

              id = em_channel.subscribe &blk
              push payload('pusher_internal:subscription_succeeded', summary_info.to_json)

              Slanger.debug "PresenceChannel joined em_channel: #{id} public_subscription_id: #{public_subscription_id}"

              public_to_em_channel_table[public_subscription_id] = id
            end
          end
        end
      end

      def summary_info
        {presence: {
          count: roster.subscribers_count,
          ids:   roster.ids,
          hash:  roster.subscribers
        }}
      end
    end
  end
end