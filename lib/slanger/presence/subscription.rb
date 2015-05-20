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

        subscription_id = channel.join(@msg) do |m|
          Slanger.error "#{self.class} pushing #{m}"
          #m = {"channel":"presence-channel","event":"pusher_internal:member_added","data":{"user_id":"0f177369a3b71275d25ab1b44db9f95f","user_info":{"name":"SG"}}}
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
