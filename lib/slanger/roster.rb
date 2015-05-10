module Slanger
  class Roster
    attr_reader :channel_id, :internal_roster
    include Slanger::RosterAddition
    include Slanger::RosterRemoval

    def initialize(channel_id)
      @channel_id = channel_id
      @state = :initial

      result = Slanger::Redis.hgetall_sync(channel_id)
      @internal_roster = redis_to_hash(result)
    end

    def present?(member)
      @internal_roster.has_value? member
    end

    def summary
      [subscribers.size, ids, subscribers]
    end

    private

    def ids
      subscribers.map(&:first)
    end

    def subscribers
      Hash[@internal_roster.values.map { |v| [v['user_id'], v['user_info']] }]
    end

    def redis_to_hash(array)
      array.each_slice(2).to_a.inject({}) do |result, (k,v)|
        result[k]= eval(v)
        result
      end
    end

  end
end
