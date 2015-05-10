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
  class PresenceChannel < Channel
    include PresenceChannelJoining
    include PresenceChannelLeaving
    include PresenceChannelStatusChange

    def initialize(*args)
      super *args

    end

    # Send an event received from Redis to the EventMachine channel
    def dispatch(message, channel_id)
      Slanger.debug "PresenceChannel dispatch incoming channel_id: #{channel_id} msg: #{message}"

      if channel_id =~ /^slanger:/
        # Messages received from the Redis channel slanger:*  carry info on
        # roster. Update our subscribers accordingly.
        handle_slanger_connection_notification message
      else
        push message.to_json
      end
    end

    # This is used map public subscription ids to em channel subscription ids.
    # em channel subscription ids are incremented integers, so they cannot
    # be used as keys in distributed system because they will not be unique
    def public_to_em_channel_table
      @public_to_em_channel_table ||= {}
    end

    private

    def roster
      @roster ||= load_roster
    end

    def load_roster
      roster = Roster.new(channel_id)

      Fiber.new do
        roster.fetch
      end.resume

      roster
    end

  end
end
