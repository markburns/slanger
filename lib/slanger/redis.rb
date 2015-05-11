# Redis class.
# Interface with Redis.

require 'forwardable'

module Slanger
  module Redis
    extend Forwardable

    def_delegator  :publisher, :publish
    def_delegators :subscriber, :subscribe
    def_delegators :regular_connection, :hgetall, :hdel, :hset, :hincrby, :sadd

    def hgetall_sync(key)
      sync_redis_connection.hgetall key
    end

    private

    def regular_connection
      @regular_connection ||= new_connection
    end

    def publisher
      @publisher ||= new_connection
    end

    def subscriber
      @subscriber ||= new_connection.pubsub.tap do |c|
        c.on(:message) do |channel, message|
          message = JSON.parse message
          c = Channel.from message['channel']
          c.dispatch message, channel
        end
      end
    end

    def new_connection
      EM::Hiredis.connect Slanger::Config.redis_address
    end

    def sync_redis_connection
      @sync_redis_connection ||= ::Redis.new url: Slanger::Config.redis_address
    end

    extend self
  end
end
