module Slanger
  class PresenceSubscription < Subscription
    def subscribe
      return handle_invalid_signature if invalid_signature?

      unless channel_data?
        return connection.error({
          message: "presence-channel is a presence channel and subscription must include channel_data"
        })
      end

      subscription_id = channel.join(@msg, callback)
    end
    private

    def callback
      Proc.new do
        Slanger.debug "PresenceSubscription completed, send pusher_internal:subscription_succeeded"

        Fiber.neww do
          connection.send_payload(
            channel_id,
            'pusher_internal:subscription_succeeded',
            channel.summary_info
          )
        end

        #send_message msg

        Slanger.debug "#{self.class} subscribed socket_id: #{socket_id} to channel_id: #{channel_id}"
      end
    end


    def channel_data?
      @msg['data']['channel_data']
    end
  end
end
