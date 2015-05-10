module Slanger
  class Roster
    attr_reader :channel_id, :internal_roster
    include Slanger::RosterAddition
    include Slanger::RosterRemoval

    def initialize(channel_id)
      @channel_id = channel_id
      @state = :initial
    end

    def present?(member)
      @internal_roster.has_value? member
    end

    def summary
      [subscribers.size, ids, subscribers]
    end

    def fetch
      return unless initial?

      perform_fetch
    end

    def perform_fetch
      Slanger.debug "hgetall #{channel_id} start"

      Fiber.new do
        @state = :fetching

        Slanger::Redis.hgetall(channel_id).
          callback(&callback).
          errback(&fetch_error)

        @state = :waiting
        Fiber.yield
      end.resume

      @state = :complete
    end

    def callback
      lambda do |res|
        Slanger.debug "inside callback #{Fiber.current}"
        @internal_roster = redis_to_hash(res)
        Slanger.debug "Redis #{__method__}(#{channel_id}): formatted_roster: #{@internal_roster}"

        if waiting?
          Slanger.debug "waiting"
          @state = :complete
          Fiber.current.resume
        else
          Slanger.debug "not waiting #{@state}"
          return @state = :complete
        end
      end
    end
    def waiting?
      @state  == :waiting
    end

    def fetching?
      @state  == :fetching
    end

    def complete?
      @state  == :complete
    end

    def initial?
      @state  == :initial
    end

    private

    def ids
      subscribers.map(&:first)
    end

    def subscribers
      Hash[@internal_roster.values.map { |v| [v['user_id'], v['user_info']] }]
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
