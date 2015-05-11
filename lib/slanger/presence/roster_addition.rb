module Slanger
  module Presence
    module RosterAddition
      def add(node_id, subscription_id, member, on_add_callback)
        Slanger.debug "Roster adding to redis #{subscription_id} = #{member}"

        Slanger::Redis.sadd(channel_id, member).
          callback(&addition_success(node_id, subscription_id, member, on_add_callback)).
          errback(&addition_error(node_id: node_id, subscription_id: subscription_id, member: member))
      end

      def add_internal(node_id, subscription_id, member)
        @internal_roster[member] ||= {}
        @internal_roster[member][node_id] ||= []
        @internal_roster[member][node_id] << subscription_id
      end

      private

      def addition_success(node_id, subscription_id, member, on_add_callback)
        Proc.new do |res|
          Slanger.debug "roster.add successful node_id: #{Slanger::Service.node_id} channel_id: #{channel_id} subscription_id: #{subscription_id}, member: #{member} internal_roster: #{@internal_roster}"
          user_id = member["user_id"]
          Slanger::Redis.sadd("slanger-roster-#{channel_id}-user-#{user_id}", subscription_id).
            errback(&addition_error(channel_id, subscription_id, member))

          on_add_callback.call
          add_internal node_id, subscription_id, member
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

