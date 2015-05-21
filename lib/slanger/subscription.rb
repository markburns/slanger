module Slanger
  class Subscription
    DIGEST = OpenSSL::Digest::SHA256.new

    attr_accessor :connection, :socket
    delegate :push_payload, :push_message, :error, :socket_id, to: :connection

    def initialize socket, socket_id, msg
      @connection = Connection.new socket, socket_id
      @msg        = msg
    end

    def subscribe
      msg = @msg.dup
      msg["socket_id"] = socket_id
      subscription_id = channel.join(msg) { |m| push_message m }

      Slanger.debug "#{self.class} subscribed socket_id: #{socket_id} to channel_id: #{channel_id} subscription_id: #{subscription_id}"

      push_payload channel_id, 'pusher_internal:subscription_succeeded'

      subscription_id
    end

    private

    def channel
      Channel.from channel_id
    end

    def channel_id
      @msg['data']['channel']
    end

    def token(channel_id, params=nil)
      to_sign = [socket_id, channel_id, params].compact.join ':'

      OpenSSL::HMAC.hexdigest DIGEST, Slanger::Config.secret, to_sign
    end

    def invalid_signature?
      token(channel_id, data) != auth.split(':')[1]
    end

    def auth
      @msg['data']['auth']
    end

    def data
      @msg['data']['channel_data']
    end

    def handle_invalid_signature
      message = "Invalid signature: Expected HMAC SHA256 hex digest of "
      message << "#{socket_id}:#{channel_id}, but got #{auth}"

      if ENV["DEBUGGER"]
      #TODO: remove
        message << "correct signature: #{token(channel_id, data)}"
      end

      error({ message: message})
      nil
    end
  end
end
