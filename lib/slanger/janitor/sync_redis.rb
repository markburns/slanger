module Slanger
  module Janitor
    module SyncRedis
      private

      def redis
        @redis ||= Slanger::Redis.sync_redis_connection
      end
    end
  end
end
