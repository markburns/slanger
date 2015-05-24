module Slanger
  module SyncRedis
    private

    def redis
      @redis ||= Slanger::Redis.sync_redis_connection
    end

    delegate :srem, :sadd, :smembers, :hgetall, :hset, :hdel, to: :redis
  end
end
