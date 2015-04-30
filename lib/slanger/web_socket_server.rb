require 'eventmachine'
require 'em-websocket'

module Slanger
  module WebSocketServer


    def run
      EM.epoll
      EM.kqueue

      EM.run do
        options = {
          host:    Slanger::Config[:websocket_host],
          port:    Slanger::Config[:websocket_port],
          debug:   Slanger::Config[:debug],
          app_key: Slanger::Config[:app_key]
        }

        if Slanger::Config[:tls_options]
          options.merge! secure: true,
                         tls_options: Slanger::Config[:tls_options]
        end

        EM::WebSocket.start options do |ws|
          attach_handlers ws
          # Also subscribe the slanger daemon to a Redis channel used for events concerning subscriptions.
          Slanger::Redis.subscribe 'slanger:connection_notification'
        end
      end
    end

    def attach_handlers(ws)
      # Keep track of handler instance in instance of EM::Connection to ensure a unique handler instance is used per connection.
      ws.class_eval    { attr_accessor :connection_handler, :health_check }

      # Delegate connection management to handler instance.
      ws.onopen        { |handshake|
        if handshake.headers["health-check"]
          ws.health_check = true
        else
          Slanger.info "Websocket onopen handshake #{handshake}"
          handler = Slanger::Config.socket_handler.new(ws, handshake)
          ws.connection_handler = handler
        end
      }

      ws.onmessage     { |msg|
        Slanger.info "Websocket onmessage msg: #{msg.inspect}"
        ws.connection_handler.onmessage msg
      }
      ws.onclose       {
        #no-op for healthchecks
        unless ws.health_check
          Slanger.info "Websocket onclose: #{ws}"
          ws.connection_handler.onclose
        end
      }
    end


    extend self
  end
end
