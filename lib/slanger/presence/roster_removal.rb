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
        @user_mapping.delete params.user_id
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
          user_id = remove_internal(params)

          Slanger.debug "internal_roster: #{@internal_roster}"

          if user_in_roster?(user_id)
            blk.call
          else
            user_info = @user_mapping.delete(user_id) || {}
            member = member_from_user_id(user_id)

            Slanger::Redis.srem(params.channel_key, member.to_json) do |res|
              blk.call true, member
            end
          end

          Slanger.debug "Roster#remove successful channel_id: #{channel_id} user_node_key: #{params.full} internal_roster: #{@internal_roster}"
        end
      end

      def member_from_user_id(user_id)
        redis = Slanger::Redis.sync_redis_connection
        members = redis.smembers "slanger-roster-presence-abcd"
        members.map{|a| JSON.parse(a)}.find{|u| user_id==u["user_id"]}
      end


      def removal_error(params)
        Proc.new do |e|
          Slanger.error "Roster#remove failed #{e} params: #{params.full}"
        end
      end

    end

  end
end
