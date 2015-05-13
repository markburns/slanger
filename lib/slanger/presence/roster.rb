module Slanger
  module Presence
    class Roster
      attr_reader :channel_id, :internal_roster, :user_mapping
      include RosterAddition
      include RosterRemoval

      def initialize(channel_id)
        @channel_id = channel_id
        redis_roster = Slanger::RedisRoster.new(channel_id)
        @internal_roster = redis_roster.internal_roster
        @user_mapping    = redis_roster.user_mapping
      end

      def present?(member)
        @internal_roster.has_key? member
      end

      def subscribers_count
        subscribers.size
      end

      def ids
        subscribers.map(&:first)
      end

      def subscribers
        @user_mapping
      end
    end
  end
end
