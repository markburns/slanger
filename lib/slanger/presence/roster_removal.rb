module Slanger
  module Presence
    module RosterRemoval
      def remove(node_id, subscription_id, update_redis=true, &blk)
        user_id = internal_roster[node_id].delete(subscription_id) rescue nil

        if internal_roster[node_id].blank?
          internal_roster.delete node_id 
        end

        user = from_user_id(user_id)

        if update_redis
          hdel(roster_node_key(node_id), subscription_id)
        end

        if user_in_roster?(user_id)
          blk.call false, user if blk
        else
          @user_mapping.delete(user_id)

          if update_redis
            srem(roster_channel_key, user.to_json)
          end

          blk.call true, user if blk
        end

        Slanger.debug "Roster#remove successful channel_id: #{channel_id} #{subscription_id} internal_roster: #{@internal_roster}"
      end

      def user_in_roster?(user)
        internal_roster.values.any?{|n| n.values.include?(user)}
      end

      private

      def from_user_id(user_id)
        users = smembers roster_channel_key
        users.map{|a| JSON.parse(a)}.find{|u| user_id==u["user_id"]}
      end
    end
  end
end
