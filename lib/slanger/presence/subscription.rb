module Slanger
  module Presence
    class Subscription < Slanger::Subscription
      def subscribe
        return handle_invalid_signature if invalid_signature?

        unless channel_data?
          return connection.error({
            message: "presence-channel is a presence channel and subscription must include channel_data"
          })
        end

        msg = @msg.dup
        msg["socket_id"]=socket_id
        subscription_id = channel.join(@msg) do |m|
          byebug
          push_message m
        end
      end


      private

      def channel_data?
        @msg['data']['channel_data']
      end
    end
  end
end
