module Slanger
  class RedisRoster
    def self.fetch(channel_id)
      new(channel_id).fetch
    end

    def initialize(channel_id)
      @channel_id= channel_id
    end

    attr_reader :channel_id

    def fetch
      redis = Slanger::Redis.sync_redis_connection

      users = redis.smembers "slanger-roster-#{channel_id}"
      users = users.map{|m| JSON.parse(m)}

      node_ids = Slanger::Service.present_node_ids

      node_ids.each_with_object({}) do |node_id, roster|
        subscriptions = redis.hgetall "slanger-roster-#{channel_id}-node-#{node_id}"

        subscriptions.each do |subscription_id, user_id|
          roster[node_id] ||= {}
          roster[node_id][subscription_id] = users.find{|u| u["user_id"] == user_id }
        end
      end

    end

    private

    def redis_to_hash(array)
      array.each_slice(2).to_a.each_with_object({}) do |(k,v), result|
        result[k]= JSON.parse(v)
      end
    end
  end
end
