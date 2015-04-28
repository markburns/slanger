require 'eventmachine'
require 'em-websocket'

module Slanger
  module WebSocketServer
    def run
      EM.epoll
      EM.kqueue
      @all_websockets = []

      EM.run do
        options = {
          host:    Slanger::Config[:websocket_host],
          port:    Slanger::Config[:websocket_port],
          debug:   Slanger::Config[:debug],
          app_key: Slanger::Config[:app_key]
        }

        if Slanger::Config[:tls_options]
          options.merge!(
            secure: true,
            tls_options: Slanger::Config[:tls_options]
          )
        end

        start(options) do |ws|
          attach_event_handlers ws
        end
      end
    end

    def attach_event_handlers(ws)
      # Keep track of handler instance in instance of EM::Connection to ensure a unique handler instance is used per connection.
      ws.class_eval    { attr_accessor :connection_handler, :health_check }

      # Delegate connection management to handler instance.
      ws.onopen        { |handshake|
        if handshake.headers["health-check"]
          ws.health_check = true
        else
          Slanger.info "Websocket onopen handshake #{handshake.inspect}"
          @all_websockets << ws
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
          Slanger.info "Websocket onclose socket_id: #{ws}"
          ws.connection_handler.onclose
          @all_websockets.delete ws
        end
      }
    end

    def start(options, &blk)
      args = [options[:host], options[:port], EventMachine::WebSocket::Connection, options]

      Slanger.info "Starting websocket server #{args}"

      EventMachine.start_server(*args) do |ws|
        blk.call(ws)
      end
    end

    def stop(signature)
      Slanger.info "Stopping websocket server #{signature}"
      @all_websockets.each do |ws|


      end

      EventMachinea.stop_server signature
    end

    extend self
  end
end
