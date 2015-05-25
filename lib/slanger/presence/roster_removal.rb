module Slanger
  module Presence
    module RosterRemoval
      def remove(node_id, subscription_id, update_redis=true, &blk)
        params = RosterParams.new(channel_id, node_id, subscription_id)

        user_id = internal_roster[node_id].delete(subscription_id) rescue nil

        if internal_roster[params.node_id].blank?
          internal_roster.delete params.node_id 
        end

        user = from_user_id(params, user_id)

        if update_redis
          hdel(params.node_key, params.subscription_id)
        end

        if user_in_roster?(user_id)
          blk.call false, user if blk
        else
          @user_mapping.delete(user_id)

          if update_redis
            srem(params.channel_key, user.to_json)
          end

          blk.call true, user if blk
        end

        Slanger.debug "Roster#remove successful channel_id: #{channel_id} user_node_key: #{params.full} internal_roster: #{@internal_roster}"
      end

      def user_in_roster?(user)
        internal_roster.values.any?{|n| n.values.include?(user)}
      end

      private

      def from_user_id(params, user_id)
        users = smembers params.channel_key
        users.map{|a| JSON.parse(a)}.find{|u| user_id==u["user_id"]}
      end
    end
  end
end
