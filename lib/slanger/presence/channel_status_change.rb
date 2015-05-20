module Slanger
  module Presence
    module ChannelStatusChange
      private

      def update_slanger_nodes_about_presence_change(payload, retry_count=0)
        payload[:node_id] = Slanger::Service.node_id
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
        node_id = message["node_id"]
        return if node_id.to_s == Slanger.node_id.to_s

        subscription_id = message["subscription_id"]

        if message["online"]
          member = message['channel_data']
          roster.add_internal(node_id, subscription_id, member)
        else
          roster.remove_internal RosterParams.new(message["channel_id"], node_id, subscription_id)
        end
      end
    end
  end
end
