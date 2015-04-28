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
      Rack::Handler::Thin.run Slanger::ApiServer, Host: Slanger::Config.api_host, Port: Slanger::Config.api_port
      @websocket_server_signature = Slanger::WebSocketServer.run
    rescue
      remove_pid!
    end

    def stop
      raise if websocket_server_signature.nil?

      Slanger::WebSocketServer.stop(websocket_server_signature)
      EM.stop if EM.reactor_running?

      remove_pid!
    end

    private

    def create_pid!
      if pid_file
        Slanger.logger.info "Creating pid: #{pid_file} #{Process.pid}"
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
