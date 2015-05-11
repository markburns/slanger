module Slanger
  module Presence
    module ChannelStatusChange
      private

      def update_slanger_nodes_about_presence_change(payload, retry_count=0)
        Slanger.debug "Redis send slanger:connection_notification #{payload}, retry_number: #{retry_count}"

        # Send a subscription notification to the global slanger:connection_notification
        # channel.
        Slanger::Redis.
          publish('slanger:connection_notification', payload.to_json).
          errback {
            if retry_count != 5
              update_slanger_nodes_about_presence_change payload, retry_count.succ
            else
              Slanger.debug "Retries failed, not publishing slanger:connection_notification(#{payload}, #{retry_count})"
            end
          }
      end

      def handle_slanger_connection_notification(message)
        Slanger.debug "incoming message #{__method__} #{message}"

        if message['online']
          member = message['channel_data']
          # Don't tell the channel subscribers a new member has been added if the subscriber data
          # is already present in the roster hash, e.g. multiple browser windows open.
          if roster.present?(member)
            Slanger.debug "Roster member already present in roster not sending pusher_internal:member_added"
          else
            Slanger.debug "Roster member is absent from roster, send pusher_internal:member_added"
            push payload('pusher_internal:member_added', member)
          end

          roster.add_internal message["node_id"], message['subscription_id'], member
        else
          # Don't tell the channel subscriptions the member has been removed if the subscriber data
          # still remains in the roster hash, e.g. multiple browser windows open.
          member = roster.remove_internal message['subscription_id']
          if member && !roster.present?(member)
            push payload('pusher_internal:member_removed', { user_id: member['user_id'] })
          end
        end
      end
    end
  end
end
