module Slanger
  module Presence
    class Roster
      attr_reader :channel_id, :internal_roster
      include RosterAddition
      include RosterRemoval

      def initialize(channel_id)
        @channel_id = channel_id
        @internal_roster = Slanger::RedisRoster.new(channel_id).fetch
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
        Hash[@internal_roster.keys.map { |v| [v['user_id'], v['user_info']] }]
      rescue
        byebug
        {}
      end
    end
  end
end
