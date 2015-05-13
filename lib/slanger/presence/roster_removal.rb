module Slanger
  module Presence
    module RosterRemoval
      def remove(node_id, subscription_id, &blk)
        params = RosterParams.new(channel_id, node_id, subscription_id)
        Slanger.debug "removing from redis #{params.full}"

        Slanger::Redis.hdel(params.node_key, subscription_id).
          callback(&removal_success(params, &blk)).
          errback( &removal_error(params))
      end

      def user_in_roster?(user)
        internal_roster.values.any?{|n| n.values.include?(user)}
      end

      def remove_internal(params)
        user = internal_roster[params.node_id].delete(params.subscription_id)
      rescue NoMethodError
        user = nil
      ensure
        remove_blank_nodes!(params, internal_roster)
        return user
      end

      def remove_blank_nodes!(params, roster)
        if roster[params.node_id].blank?
          roster.delete params.node_id
        end
      end

      private

      def removal_success(params, &blk)
        Proc.new do |res|
          user = remove_internal(params)
          if user_in_roster?(user)
            blk.call
          else
            @user_mapping.delete(user["user_id"]) rescue nil

            Slanger::Redis.srem(params.channel_key, user.to_json) do
              blk.call
            end
          end

          Slanger.debug "roster.remove successful channel_id: #{channel_id} user_node_key: #{params.full} internal_roster: #{@internal_roster}"
        end
      end

      def removal_error(params)
        Proc.new do |e|
          Slanger.error "roster.remove failed #{e} params: #{params.full}"
        end
      end

    end

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
