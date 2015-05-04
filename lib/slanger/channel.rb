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
    extend  Forwardable

    def_delegators :em_channel, :push
    attr_reader :channel_id

    class << self
      def from channel_id
        klass = channel_id[/^presence-/] ? PresenceChannel : Channel

        byebug
        klass.find_or_create_by_channel_id(channel_id)
      end

      def find_or_create_by_channel_id(channel_id)
        lookup(channel_id) || begin

          instance = create(channel_id: channel_id)
          all[channel_id]  = instance
        end
      end

      def lookup(channel_id)
        all[channel_id]
      end

      def create(params = {})
        new(params)
      end

      def all
        @all ||= {}
      end

      def unsubscribe channel_id, subscription_id
        from(channel_id).try :unsubscribe, subscription_id
      end

      def send_client_message msg
        from(msg['channel']).try :send_client_message, msg
      end
    end

    def initialize(attrs)
      @channel_id = attrs.with_indifferent_access[:channel_id]
      Slanger::Redis.subscribe channel_id
    end

    def em_channel
      @em_channel ||= EM::Channel.new
    end

    def subscribe(*a, &blk)
      change_subscriber_count __method__, +1, *a, &blk
    end

    def unsubscribe *a, &blk
      change_subscriber_count __method__, -1, *a, &blk
    end

    def change_subscriber_count(name, by, *a, &blk)
      Slanger::Redis.hincrby('channel_subscriber_count', channel_id, by).
        callback on_subscription_change_callback(name, *a, &blk)
    end

    def on_subscription_change_callback(type, *args, &blk)
      Proc.new do |value|
        em_channel.send(type, *a, &blk)

        name, expected_count =
          if type == :subscribe
            ["channel_vacated", 0]
          else
            ["channel_occupied",1]
          end

        Slanger::Webhook.post name: name, channel: channel_id if value == expected_count
      end
    end


    # Send a client event to the EventMachine channel.
    # Only events to channels requiring authentication (private or presence)
    # are accepted. Public channels only get events from the API.
    def send_client_message(message)
      Slanger::Redis.publish(message['channel'], message.to_json) if authenticated?
    end

    # Send an event received from Redis to the EventMachine channel
    # which will send it to subscribed clients.
    def dispatch(message, channel_id)
      push(message.to_json) unless channel_id =~ /^slanger:/
    end

    def authenticated?
      channel_id =~ /^private-/ || channel_id =~ /^presence-/
    end
  end
end
