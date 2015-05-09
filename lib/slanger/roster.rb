module Slanger
  class Roster
    extend Forwardable
    def_delegators :internal_roster, :delete, :has_value?, :[], :[]=
    attr_reader :channel_id, :internal_roster
    include Slanger::RosterAddition
    include Slanger::RosterRemoval

    def initialize(channel_id)
      @channel_id = channel_id
      @internal_roster = {}
    end

    def present?(member)
      @internal_roster.has_value? member
    end

    def ids
      subscribers.map(&:first)
    end

    def subscribers
      Hash[@internal_roster.values.map { |v| [v['user_id'], v['user_info']] }]
    end

    def fetch
      Slanger.debug "hgetall #{channel_id} start"

      Slanger::Redis.hgetall(channel_id).
        callback(&fetch_success).
        errback(&fetch_error)
    end

    private

    def fetch_success
      Proc.new do |res|
        formatted_roster = redis_to_hash(res)
        Slanger.debug "Redis #{__method__}(#{channel_id}): formatted_roster: #{formatted_roster}"

        @internal_roster ||= {}
        @internal_roster.merge! formatted_roster
      end
    end

    def fetch_error
      Proc.new do |e|
        Slanger.error "Redis #{__method__}(#{channel_id}): error: #{e}"
      end
    end

    def redis_to_hash(array)
      array.each_slice(2).to_a.inject({}) do |result, (k,v)| 
        result[k]= eval(v)
        result
      end
    end

  end
end
