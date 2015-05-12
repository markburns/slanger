module Slanger
  module Presence
    module RosterRemoval
      def remove(node_id, user, subscription_id, &blk)
        params = Params.new(channel_id, node_id, user, subscription_id)
        Slanger.debug "removing from redis #{params.full}"

        Slanger::Redis.srem(params.user_node_key, subscription_id).
          callback(&removal_success(params, &blk)).
          errback( &removal_error(params))
      end

      def remove_user_node?(h, user, node_id)
        h[user][node_id].empty?
      rescue NoMethodError
        nil
      end

      def remove_user?(h, user)
        h.keys.include?(user) && h[user].blank?
      end

      def remove_internal(params, roster=@internal_roster)
        roster[params.user][params.node_id].delete params.subscription_id

        remove_blank_nodes_and_users!(params, roster)

        roster
      rescue NoMethodError
        return roster
      end

      def remove_blank_nodes_and_users!(params, roster)
        remove_blank_user_nodes!(params, roster)

        if remove_user?(roster, params.user)
          roster.delete params.user
          Slanger::Redis.srem(params.channel_key, params.user)
        end
      end

      def remove_blank_user_nodes!(params, roster)
        if remove_user_node?(roster, params.user, params.node_id)
          roster[params.user].delete params.node_id
        end
      end

      private

      def removal_success(params, &blk)
        Proc.new do |res|
          Slanger::Redis.smembers(params.user_node_key) do |m|
            blk.call

          end

          remove_internal(params)
          Slanger.debug "roster.remove successful channel_id: #{channel_id} user_node_key: #{params.full} internal_roster: #{@internal_roster}"
        end
      end

      def removal_error(params)
        Proc.new do |e|
          Slanger.error "roster.remove failed #{e} params: #{params.full}"
        end
      end

      class Params < Struct.new :channel_id, :node_id, :user, :subscription_id
        def channel_key
          "slanger-roster-#{channel_id}"
        end

        def user_node_key
          "#{channel_key}-user-#{user_id}-node-#{node_id}"
        end

        def full
           "#{user_node_key} subscription-id: #{subscription_id}"
        end

        def user_id
          user["user_id"]
        end
      end
    end
  end
end
