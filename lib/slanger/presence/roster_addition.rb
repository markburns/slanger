module Slanger
  module Presence
    module RosterAddition
      def add(node_id, subscription_id, member, on_add_callback=nil, &roster_add_block)
        Slanger.debug "Roster adding to redis node_id: #{node_id} subscription_id:#{subscription_id} member: #{member}"

        params = RosterParams.new(channel_id, node_id, subscription_id)

        member["user_info"] ||= {}

        added_to_roster = sadd(params.channel_key, member.to_json)

        user_id = member["user_id"]
        @user_mapping[user_id]=member["user_info"]
        hset(params.node_key, params.subscription_id, user_id)
        add_internal params.node_id, params.subscription_id, user_id


        if only_reference?(member["user_id"])
          on_add_callback.call added_to_roster if on_add_callback

          roster_add_block.call added_to_roster if roster_add_block
        end
      end


      def add_internal(node_id, subscription_id, user_id)
        @internal_roster[node_id] ||= {}
        @internal_roster[node_id][subscription_id] = user_id
      end
    end
  end
end

