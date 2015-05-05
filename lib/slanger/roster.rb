require "fiber"

module Slanger
  class Roster
    extend Forwardable
    def_delegators :internal_roster, :delete, :has_value?, :[], :[]=
    attr_reader :channel_id, :internal_roster

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

    def add(key, value, on_add_callback)
      # Add subscription info to Redis.
      Slanger::Redis.hset(channel_id, key, value).
        callback{
        Slanger.debug "roster_add successful channel_id: #{channel_id} key: #{key}, value: #{value}"
        on_add_callback.call
      }.errback {|e|
        Slanger.error "roster_add failed #{e} channel_id: #{channel_id} key: #{key} value: #{value}"
      }
    end


    def remove(key)
      Slanger.debug "removing from redis"
      # Remove subscription info from Redis.
      Slanger::Redis.hdel(channel_id, key).callback do
        Slanger.debug "roster_remove successful channel_id: #{channel_id} key: #{key}"
      end.errback do |e|
        Slanger.error "roster_remove failed #{e} channel_id: #{channel_id} key: #{key}"
      end
    end

    def fetch
      Slanger.debug "hgetall #{channel_id} start"

      Slanger::Redis.hgetall(channel_id).
        callback(&success_callback).
        errback(&error_callback)
    end

    private

    def success_callback
      Proc.new do |res|
        Slanger.debug "hgetall complete: #{channel_id} res: #{res}"
        formatted_roster = redis_to_hash(res)
        Slanger.debug "#{__method__}(#{channel_id}): formatted_roster: #{formatted_roster}"

        @internal_roster ||= {}
        @internal_roster.merge! formatted_roster
      end
    end

    def error_callback
      Proc.new do |e|
        Slanger.error "get_roster(#{channel_id}) error: #{e}"
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
