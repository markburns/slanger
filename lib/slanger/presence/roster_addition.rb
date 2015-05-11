module Slanger
  module Presence
    module RosterAddition
      def add(subscription_id, member, on_add_callback)
        Slanger.debug "Roster adding to redis #{subscription_id} = #{member}"

        Slanger::Redis.sadd(channel_id, member).
          callback(&addition_success(subscription_id, member, on_add_callback)).
          errback(&addition_error(subscription_id, member))
      end

      def add_internal(subscription_id, member)
        @internal_roster[Slanger.node_id] ||= {}
        @internal_roster[Slanger.node_id][member] ||= []
        @internal_roster[Slanger.node_id][member] << subscription_id
      end

      private

      def addition_success(subscription_id, member, on_add_callback)
        Proc.new do |res|
          Slanger.debug "roster.add successful channel_id: #{channel_id} subscription_id: #{subscription_id}, member: #{member} internal_roster: #{@internal_roster}"
          user_id = member["user_id"]
          Slanger::Redis.sadd("slanger-roster-#{channel_id}-user-#{user_id}", subscription_id).
            errback(&addition_error(channel_id, subscription_id, member))

          on_add_callback.call
          add_internal subscription_id, member
        end
      end

      def addition_error(*args)
        Proc.new do |e|
          Slanger.error "Redis add failed #{e} args: #{args}"
        end
      end
    end
  end
end

