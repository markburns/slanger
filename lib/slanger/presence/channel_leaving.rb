module Slanger
  module Presence
    module ChannelLeaving
      def leave(public_subscription_id)
        Slanger.debug "Leave presence channel public_subscription_id: #{public_subscription_id}"

        em_channel.unsubscribe(public_to_em_channel_table.delete(public_subscription_id))

        roster.remove(public_subscription_id) do
          Slanger.debug "Roster removal complete for public_subscription_id: #{public_subscription_id}"

          update_slanger_nodes_about_presence_change(
            node_id: Slanger::Service.node_id,
            subscription_id: public_subscription_id,
            online: false,
            channel: channel_id
          )
        end
      end
    end
  end
end
