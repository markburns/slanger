module Slanger
  module Presence
    module RosterAddition
      def add(node_id, subscription_id, user, on_add_callback=nil, persist_to_redis=true, &roster_add_block)
        Slanger.debug "Roster adding to redis node_id: #{node_id} subscription_id:#{subscription_id} user: #{user}"

        user["user_info"] ||= {}

        user_id = user["user_id"]
        @user_mapping[user_id] = user["user_info"]

        @internal_roster[node_id] ||= {}
        @internal_roster[node_id][subscription_id] = user_id

        added_to_roster = if persist_to_redis
                            hset(roster_node_key(node_id), subscription_id, user_id)
                            sadd(roster_channel_key, user.to_json)
                          end

        if only_reference?(user_id)
          on_add_callback.call added_to_roster if on_add_callback

          roster_add_block.call added_to_roster if roster_add_block
        end
      end

      def roster_channel_key
        "slanger-roster-#{channel_id}"
      end

      def roster_node_key(node_id)
        "#{roster_channel_key}-node-#{node_id}"
      end
    end
  end
end

