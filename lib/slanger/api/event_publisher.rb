module Slanger
  module Api
    class EventPublisher < Struct.new(:channels, :event)
      def self.publish(channels, event_name, event_body, socket_id)
        event = Slanger::Api::Event.new(event_name, event_body, socket_id)

        new(channels, event).publish
      end

      def publish
        Array(channels).each do |c|
          publish_event(c)
        end
      end

      private

      def publish_event(channel_id)
        Slanger::Redis.publish(channel_id, event.payload(channel_id))
      end

    end
  end
end


