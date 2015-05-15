require 'eventmachine'
require 'em-websocket'

module Slanger
  module WebSocketServer
    def run(options)
      EM.epoll
      EM.kqueue
      Slanger.debug "Websocket server run: #{options}"

      EM.run do
        unless @first_run
          @first_run=true
          # Also subscribe the slanger daemon to a Redis channel used for events concerning subscriptions.
          Slanger::Redis.subscribe 'slanger:connection_notification'
          Slanger::Janitor.register_roll_call!

          EM::WebSocket.start options do |ws|
            attach_handlers ws
          end
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
          Slanger.info "Websocket onopen"
          handler = Slanger::Config.socket_handler.new(ws, handshake)
          ws.connection_handler = handler
          Slanger.info "Websocket onopen complete socket_id: #{handler.socket_id}"
          puts "="*500
        end
      }

      ws.onmessage     { |msg|
        Slanger.info "Websocket onmessage socket_id: #{ws.connection_handler.socket_id} msg: #{msg}"
        ws.connection_handler.onmessage msg
      }

      ws.onclose       {
        #no-op for healthchecks
        unless ws.health_check
          Slanger.info "Websocket onclose socket_id: #{ws.connection_handler.socket_id}"
          ws.connection_handler.onclose
        end
      }
    end


    extend self
  end
end
