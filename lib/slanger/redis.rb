# Redis class.
# Interface with Redis.

module Slanger
  module Redis
    delegate :publish,                         to: :publisher
    delegate :on, :subscribe,                  to: :subscriber
    delegate :hgetall, :hdel, :hset, :hincrby, to: :regular_connection

    private

    def regular_connection
      @regular_connection ||= new_connection
    end

    def publisher
      @publisher ||= new_connection
    end

    def subscriber
      @subscriber ||= new_connection
    end

    def new_connection
      EM::Hiredis.connect Slanger::Config.redis_address
    end

    extend self

    # Dispatch messages received from Redis to their destination channel.
    on(:message) do |channel, message|
      message = JSON.parse message
      c = Slanger::WebSocket::Channel.from message['channel']
      c.dispatch message, channel
    end
  end
end
