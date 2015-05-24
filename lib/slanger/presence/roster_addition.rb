module Slanger
  module Presence
    module RosterAddition
      def add(node_id, subscription_id, member, on_add_callback=nil, &roster_add_block)
        Slanger.debug "Roster adding to redis node_id: #{node_id} subscription_id:#{subscription_id} member: #{member}"

        params = RosterParams.new(channel_id, node_id, subscription_id)

        member["user_info"] ||= {}

        Slanger::Redis.
          sadd(params.channel_key, member.to_json).
          callback(&main_presence_key_success(params, member, on_add_callback, &roster_add_block)).
          errback(&addition_error(params, member: member))
      end


      def add_internal(node_id, subscription_id, member)
        @internal_roster[node_id] ||= {}
        @internal_roster[node_id][subscription_id] = member
      end

      private

      def main_presence_key_success(params, member, on_add_callback, &roster_add_block)
        Proc.new do |res|
          Slanger.debug "Roster#add successful #{params.full}, member: #{member}"
          user_id = member["user_id"]
          added_to_roster = res == 1
          @user_mapping[user_id]=member["user_info"]

          Slanger::Redis.hset(params.node_key, params.subscription_id, user_id).
            errback(&addition_error(params, member)).
            callback(&individual_subscriber_key_success(params, member, on_add_callback, added_to_roster, &roster_add_block))
        end
      end

      def individual_subscriber_key_success(params, member, on_add_callback, added_to_roster, &roster_add_block)
        Proc.new do |*result|
          Slanger.info "Successfully added #{params.full}"
          add_internal params.node_id, params.subscription_id, member
          Slanger.info "Successfully added to internal roster"

          Slanger.debug "internal_roster: #{@internal_roster}"

          if only_reference?(member["user_id"])
            on_add_callback.call added_to_roster if on_add_callback

            roster_add_block.call added_to_roster if roster_add_block
          end
        end
      end

      def addition_error(*args)
        Proc.new do |*e|
          Slanger.error "Redis add failed #{e} args: #{args}"
        end
      end
    end
  end
end

