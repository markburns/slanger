require 'thin'
require 'rack'

#autoload logger
Slanger::Logger

module Slanger
  module Service
    attr_reader :websocket_server_signature

    def node_id
      @node_id ||= Slanger::Redis.hincrby "next-server"
    end

    def run
      Slanger::Config[:require].each { |f| require f }
      Thin::Logging.silent = true

      create_pid!
      @websocket_server_signature = Slanger::WebSocketServer.run
      Slanger.debug "websocket_server_signature: #{@websocket_server_signature}"

      connection_args = {Host: Slanger::Config.api_host, Port: Slanger::Config.api_port}

      Slanger.info "Starting API server #{connection_args}"
      Rack::Handler::Thin.run Slanger::ApiServer, connection_args
      Slanger.debug "API server started"
    rescue
      remove_pid!
    end

    def stop
      Slanger.info "Stopping websocket server"
      raise if websocket_server_signature.nil?

      Slanger::WebSocketServer.stop(websocket_server_signature)

      Slanger.info "Stopping API server"
      EM.stop if EM.reactor_running?
    ensure
      remove_pid!
    end

    private

    def create_pid!
      if pid_file
        Slanger.info "Creating pid: #{pid_file} #{Process.pid}"
        File.open(pid_file, 'w') { |f| f.puts Process.pid }
      end
    end

    def remove_pid!
      if pid_file && File.exists?(pid_file)
        FileUtils.rm pid_file
      end
    end

    def pid_file
      Slanger::Config[:pid_file]
    end

    extend self
  end
end
