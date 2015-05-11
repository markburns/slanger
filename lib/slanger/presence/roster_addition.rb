module Slanger
  module Presence
    module RosterAddition
      def add(key, value, on_add_callback)
        Slanger.debug "Roster adding to redis #{key} = #{value}"

        Slanger::Redis.hset(channel_id, key, value).
          callback(&addition_success(key, value, on_add_callback)).
          errback(&addition_error(key, value))
      end

      def add_internal(key, value)
        @internal_roster[key] = value
      end

      private

      def addition_success(key, value, on_add_callback)
        Proc.new do |res|
          Slanger.debug "roster_add successful channel_id: #{channel_id} key: #{key}, value: #{value} internal_roster: #{@internal_roster}"
          on_add_callback.call
          add_internal key, value
        end
      end

      def addition_error(key, value)
        Proc.new do |e|
          Slanger.error "roster_add failed #{e} channel_id: #{channel_id} key: #{key} value: #{value}"
        end
      end
    end
  end
end

