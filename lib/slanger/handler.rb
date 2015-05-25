# Handler class.
# Handles a client connected via a websocket connection.

require 'active_support/core_ext/hash'
require 'securerandom'
require 'signature'
require 'fiber'
require 'rack'

module Slanger
  class Handler

    attr_accessor :connection
    delegate :error, :push_payload, :socket_id, to: :connection

    def initialize(socket, handshake)
      @socket        = socket
      @handshake     = handshake
      @connection    = Connection.new(@socket)
      @subscriptions = {}
      authenticate
    end

    # Dispatches message handling to method with same name as
    # the event name
    def onmessage(msg)
      msg = JSON.parse(msg)

      msg['data'] = JSON.parse(msg['data']) if msg['data'].is_a? String

      event = msg['event'].gsub(/\Apusher:/, 'pusher_')

      if event =~ /\Aclient-/
        msg['socket_id'] = connection.socket_id
        Channel.send_client_message msg
      elsif respond_to? event, true
        send event, msg
      end

    rescue JSON::ParserError
      error({ code: 5001, message: "Invalid JSON" })
    rescue Exception => e
      error({ code: 500, message: "#{e.message}\n #{e.backtrace.join "\n "}" })
    end

    def onclose
      Slanger.debug "Node: #{Slanger.node_id} onclose unsubscribing subscriptions: #{@subscriptions}"

      @subscriptions.select { |k,v| k && v }.
        each do |channel_id, subscription_id|
          Channel.leave channel_id, subscription_id
        end
    end

    def authenticate
      Slanger.debug "authenticate app_key: #{app_key} #{socket_id}"

      if !valid_app_key? app_key
        error({ code: 4001, message: "Could not find app by key #{app_key}" })
        @socket.close_websocket
      elsif !valid_protocol_version?
        error({ code: 4007, message: "Unsupported protocol version" })
        @socket.close_websocket
      else
        connection.acknowledge_established
        Slanger.info "Authenticate successful socket_id: #{socket_id}"
      end
    end

    def valid_protocol_version?
      protocol_version.between?(3, 7)
    end

    def pusher_ping(msg)
      push_payload nil, 'pusher:pong'
    end

    def pusher_pong msg; end

    def pusher_subscribe(msg)
      Slanger.debug "#{__method__} #{msg}, \nExisting subscriptions: #{@subscriptions}"
      channel_id = msg['data']['channel']
      klass      = subscription_klass channel_id

      if @subscriptions[channel_id]
        error({ code: nil, message: "Existing subscription to #{channel_id}" })
      else
        Slanger.debug "Creating new subscription socket_id: #{socket_id} channel_id: #{channel_id} type: #{klass}"
        subscription = klass.new(connection.socket, connection.socket_id, msg)
        subscription_id = subscription.subscribe

        if subscription_id
          Slanger.debug "Subscribed socket_id: #{socket_id} to channel_id: #{channel_id} subscription_id: #{subscription_id}"
          @subscriptions[channel_id] = subscription_id
        end
      end
    end

    def pusher_unsubscribe(msg)
      Slanger.debug "#{__method__} #{msg}"
      Slanger.debug "Existing subscriptions: #{@subscriptions}"

      channel_id      = msg['data']['channel']
      subscription_id = @subscriptions.delete(channel_id)
      Slanger.debug "Deleting subscription socket_id: #{socket_id} channel_id: #{channel_id} subscription_id: #{subscription_id}"

      Channel.leave channel_id, subscription_id
    end

    private

    def app_key
      @handshake.path.split(/\W/)[2]
    end

    def protocol_version
      @query_string ||= Rack::Utils.parse_nested_query(@handshake.query_string)
      @query_string["protocol"].to_i || -1
    end

    def valid_app_key? app_key
      Slanger::Config[:app_key] == app_key
    end

    def subscription_klass channel_id
      klass = case channel_id
      when /\Aprivate-/
        Slanger::PrivateSubscription
      when /\Apresence-/
        Slanger::Presence::Subscription
      else
        Slanger::Subscription
      end
    end
  end
end
