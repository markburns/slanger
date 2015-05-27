# Channel class.
#
# Uses an EventMachine channel to let clients interact with the
# Pusher channel. Relay events received from Redis into the
# EM channel.
#

require 'eventmachine'
require 'forwardable'

module Slanger
  class Channel
    attr_reader :channel_id

    class << self
      def from channel_id
        klass = channel_id[/\Apresence-/] ? Presence::Channel : Channel

        klass.all[channel_id] ||=
          begin
            Slanger::Redis.subscribe channel_id
            klass.new(channel_id)
          end
      end

      def dispatch(message)
        from(message['channel']).dispatch message
      end

      def leave channel_id, subscription_id
        from(channel_id).try :leave, subscription_id
      end

      def send_client_message msg
        channel = from(msg['channel'])
        if channel
          channel.send_client_message msg
        else
          Slamger.error "#{__method__} Channel not found to send message: #{msg}"
        end
      end

      def all
        @all ||= {}
      end

    end

    def initialize(channel_id)
      @channel_id = channel_id
    end

    # Send an event received from Redis to the EventMachine channel
    # which will send it to subscribed clients.
    def dispatch(message)
      if channel_id =~ /\Aslanger:/
        Slanger.debug "Not dispatching slanger message for channel_id: #{channel_id} message: #{message}"
      else
        Slanger.debug "#{self.class}#dispatch: Push message to em_channel channel_id: #{channel_id} message: #{message}"
        push(message.to_json)
      end
    end


    def em_channel
      @em_channel ||= EM::Channel.new
    end

    def join(*a, &blk)
      change_subscriber_count "subscribe", +1, *a, &blk

      RandomSubscriptionId.next
    end

    class RandomSubscriptionId
      def self.next
        SecureRandom.uuid
      end
    end

    def leave *a, &blk
      change_subscriber_count "unsubscribe", -1, *a, &blk
    end

    def change_subscriber_count(type, delta, *a, &blk)
      hincrby = Slanger::Redis.hincrby('channel_subscriber_count', channel_id, delta)

      hincrby.callback do |value|
        em_channel.send(type, *a, &blk)

        trigger_webhook type, value
      end
    end

    WEBHOOK_ATTRIBUTES = {subscribe:   ["channel_occupied",1],
                          unsubscribe: ["channel_vacated", 0]}

    def trigger_webhook(type, value)
      webhook_name, trigger_value = WEBHOOK_ATTRIBUTES[type.to_sym]

      Slanger::Webhook.post name: webhook_name, channel: channel_id if value == trigger_value
    end

    def push(msg)
      Slanger.debug "Pushing message to em_channel: #{channel_id} #{msg}"

      em_channel.push msg
    end

    # Send a client event to the EventMachine channel.
    # Only events to channels requiring authentication (private or presence)
    # are accepted. Public channels only get events from the API.
    def send_client_message(message)
      if authenticated?
        Slanger.debug "#{__method__} publish to redis: #{message}"
        Slanger::Redis.publish(message['channel'], message.to_json)
      end
    end

    def authenticated?
      channel_id =~ /\Aprivate-/ || channel_id =~ /\Apresence-/
    end
  end
end
