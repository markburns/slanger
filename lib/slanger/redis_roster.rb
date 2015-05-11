module Slanger
  class RedisRoster
    def initialize(channel_id)
      @channel_id= channel_id
    end

    attr_reader :channel_id

    def fetch
      redis = Slanger::Redis.sync_redis_connection

      members = redis.smembers "slanger-roster-presence-abcd" 
      members = members.map{|m| eval m}

      node_ids = Slanger::Service.present_node_ids

      members.each_with_object({}) do |u, result|
        user_id = u["user_id"]
        node_ids.each do |node_id|
          key = "slanger-roster-#{channel_id}-node-#{node_id}-user-#{user_id}"
          subscription_ids = redis.smembers key

          result[u] ||= {}
          result[u][node_id] ||= []
          result[u][node_id] = subscription_ids
        end
      end
    end
  end
end
