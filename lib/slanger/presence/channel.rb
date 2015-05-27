# PresenceChannel class.
#
# Uses an EventMachine channel to let handlers interact with the
# Pusher channel. Relay events received from Redis into the
# EM channel. Keeps data on the subscribers to send it to clients.
#

require 'eventmachine'
require 'forwardable'
require 'fiber'

module Slanger
  module Presence
    class Channel < Slanger::Channel
      include ChannelJoining
      include ChannelLeaving
      include ChannelStatusChange

      def self.remove_invalid_nodes!(online_node_ids)
        all.values.each do |channel|
          channel.remove_invalid_nodes!(online_node_ids)
        end
      end

      def initialize(args)
        super args

        roster
      end

      # Send an event received from Redis to the EventMachine channel
      def dispatch(message)
        Slanger.debug "PresenceChannel dispatch incoming channel_id: #{channel_id} msg: #{message}"

        if message["slanger_channel"] == "slanger:connection_notification"
          # Messages received from the Redis channel slanger:*  carry info on
          # roster. Update our subscribers accordingly.
          handle_slanger_connection_notification message
        else
          push message.to_json
        end
      end

      def remove_invalid_nodes!(online_node_ids)
        roster.remove_invalid_nodes!(online_node_ids)
      end

      # This is used map public subscription ids to em channel subscription ids.
      # em channel subscription ids are incremented integers, so they cannot
      # be used as keys in distributed system because they will not be unique
      def public_to_em_channel_table
        @public_to_em_channel_table ||= {}
      end

      private

      def roster
        @roster ||= Roster.new(channel_id)
      end

      def payload(event_name, payload = {}, socket_id: nil)
        { channel: channel_id, event: event_name, data: payload, socket_id: socket_id}.to_json
      end
    end
  end
end
