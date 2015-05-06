require 'eventmachine'
require 'em-websocket'

module Slanger
  module WebSocketServer
    def run(options)
      EM.epoll
      EM.kqueue
      Slanger.debug "Websocket server run: #{options}"

      EM.run do
       # Also subscribe the slanger daemon to a Redis channel used for events concerning subscriptions.
        Slanger::Redis.subscribe 'slanger:connection_notification'

        EM::WebSocket.start options do |ws|
          attach_handlers ws
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
        Slanger.info "Websocket onmessage msg: #{msg}"
        ws.connection_handler.onmessage msg
      }
      ws.onclose       {
        #no-op for healthchecks
        unless ws.health_check
          Slanger.info "Websocket onclose socket_id: #{ws.connection_handler.connection.socket_id}"
          ws.connection_handler.onclose
        end
      }
    end


    extend self
  end
end
