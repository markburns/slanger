module Slanger
  module Presence
    module ChannelLeaving
      def leave(public_subscription_id)
        Slanger.debug "Leave presence channel public_subscription_id: #{public_subscription_id}"

        roster.remove(Slanger::Service.node_id, public_subscription_id) do |removed, user|
          em_channel.unsubscribe(public_to_em_channel_table.delete(public_subscription_id))

          if removed
            # Don't tell the channel subscriptions the member has been removed if the subscriber data
            # still remains in the roster hash, e.g. multiple browser windows open.
            push payload('pusher_internal:member_removed', user)

            Slanger.debug "Roster removal complete for public_subscription_id: #{public_subscription_id}"

            update_slanger_nodes_about_presence_change(
              subscription_id: public_subscription_id,
              online: false,
              channel: channel_id
            )
          end
        end
      end
    end
  end
end
