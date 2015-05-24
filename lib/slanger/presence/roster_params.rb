module Slanger
  module Presence
    class RosterParams < Struct.new :channel_id, :node_id, :subscription_id
      def channel_key
        "slanger-roster-#{channel_id}"
      end

      def node_key
        "#{channel_key}-node-#{node_id}"
      end

      def full
        "#{node_key} subscription-id: #{subscription_id}"
      end
    end
  end
end
