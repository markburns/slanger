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

        #ensure we send back the initial notification to the websocket
        if msg["event"] != "pusher_internal:subscription_succeeded" 
          #used in connection to ensure we don't ping back the member_added to the same socket
          msg["socket_id"] = socket_id
        end


        subscription_id = channel.join(msg) do |m|
          json = JSON.parse(m)

          unless (json["socket_id"] == socket_id) && (json["event"] == "pusher_internal:member_added")
            push_message m
          end
        end
      end


      private

      def channel_data?
        @msg['data']['channel_data']
      end
    end
  end
end
