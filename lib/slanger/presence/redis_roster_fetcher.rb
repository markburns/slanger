module Slanger
  module Presence
    class RedisRosterFetcher
      def initialize(channel_id)
        @channel_id= channel_id
      end

      attr_reader :channel_id

      def user_mapping
        users.each_with_object({}) do |u, users|
          users[u["user_id"]] = u["user_info"]
        end
      end

      def internal_roster
        node_ids = Slanger::Service.present_node_ids

        node_ids.each_with_object({}) do |node_id, roster|
          subscriptions = redis.hgetall "slanger-roster-#{channel_id}-node-#{node_id}"

          subscriptions.each do |subscription_id, user_id|
            roster[node_id] ||= {}
            roster[node_id][subscription_id] =  user_id 
          end
        end
      end

      private

      def users
        @users ||= redis.smembers "slanger-roster-#{channel_id}"
      end

      def redis
        @redis ||= Slanger::Redis.sync_redis_connection
      end

      def redis_to_hash(array)
        array.each_slice(2).to_a.each_with_object({}) do |(k,v), result|
          result[k]= JSON.parse(v)
        end
      end
    end
  end
end
