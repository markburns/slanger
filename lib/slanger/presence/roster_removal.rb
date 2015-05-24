module Slanger
  module Presence
    module RosterRemoval
      def remove(node_id, subscription_id, &blk)
        params = RosterParams.new(channel_id, node_id, subscription_id)
        Slanger.debug "removing from redis #{params.full}"

        user_id = remove_internal(params)
        hdel(params.node_key, params.subscription_id)

        Slanger.debug "internal_roster: #{@internal_roster}"

        if user_in_roster?(user_id)
          blk.call
        else
          user_info = @user_mapping.delete(user_id) || {}
          member = member_from_user_id(params, user_id)

          srem(params.channel_key, member.to_json)

          blk.call true, member
        end

        Slanger.debug "Roster#remove successful channel_id: #{channel_id} user_node_key: #{params.full} internal_roster: #{@internal_roster}"
      end

      def user_in_roster?(user)
        internal_roster.values.any?{|n| n.values.include?(user)}
      end

      def remove_internal(params)
        user_id = internal_roster[params.node_id].delete(params.subscription_id)
      rescue NoMethodError
        user_id = user_id #ensure we can return a value
      ensure
        remove_blank_nodes!(params, internal_roster)
        return user_id
      end

      def remove_blank_nodes!(params, roster)
        if roster[params.node_id].blank?
          roster.delete params.node_id
        end
      end

      private

      def member_from_user_id(params, user_id)
        redis = Slanger::Redis.sync_redis_connection
        members = redis.smembers params.channel_key
        members.map{|a| JSON.parse(a)}.find{|u| user_id==u["user_id"]}
      end
    end
  end
end
