module Slanger
  module Presence
    class Roster
      attr_reader :channel_id, :internal_roster, :user_mapping
      include RosterAddition
      include RosterRemoval

      def initialize(channel_id)
        @channel_id = channel_id
        redis_roster = RedisRosterFetcher.new(channel_id)
        @internal_roster = redis_roster.internal_roster
        @user_mapping    = redis_roster.user_mapping
      end

      def ids
        all_ids.uniq
      end

      def only_reference?(id)
        id_count_for(id)==1
      end

      def id_count_for(id)
        id_counts[id]
      end

      def all_ids
        @internal_roster.values.map(&:values).flatten
      end

      def id_counts
        @internal_roster.values.map(&:values).flatten.each_with_object({}) do |id, result|
          result[id] ||= 0
          result[id] += 1
        end
      end

      def subscribers_count
        subscribers.size
      end

      def subscribers
        @user_mapping
      end
    end
  end
end
