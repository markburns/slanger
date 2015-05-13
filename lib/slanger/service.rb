require 'thin'
require 'rack'

#autoload logger
Slanger::Logger

module Slanger
  def self.node_id
    Service.node_id
  end

  module Service
    class << self
      attr_reader :websocket_server_signature

      def run
        Slanger.debug "Slanger::Service.run"
        Slanger::Config.load
        Slanger::Config[:require].each { |f| require f }

        create_pid!
        fetch_node_id!
        start_api_server!
        start_websocket_server!
        set_online_status!
      rescue
        stop
        remove_pid!
      end

      def node_id
        @node_id ||= fetch_node_id!
      end

      def fetch_node_id!
        @node_id ||= fetch_node_id
      end

      def present_node_ids
        Slanger::Redis.sync_redis_connection.smembers("slanger-online-node-ids")
      end

      def set_online_status!
        Slanger::Redis.sync_redis_connection.sadd("slanger-online-node-ids", node_id)
      end

      def fetch_node_id
        Slanger::Redis.sync_redis_connection.hincrby("slanger-node", "next-id", 1)
      end

      def start_websocket_server!
        options = map_options_for_websocket_server(Slanger::Config)

        Slanger.info "OPTIONS #{options}"
        @websocket_server_signature = Slanger::WebSocketServer.run(options)

        Slanger.debug "websocket_server_signature: #{@websocket_server_signature}"
      end

      def map_options_for_websocket_server(options)
        opt = {
          host:    options[:websocket_host],
          port:    options[:websocket_port],
          debug:   options[:debug],
          app_key: options[:app_key]
        }

        if options[:tls_options]
          opt.merge! secure: true,
            tls_options: options[:tls_options]
        end

        opt
      end

      def start_api_server!
        Thin::Logging.silent = true
        connection_args = map_options_for_api_server Slanger::Config

        Slanger.info "Starting API server #{connection_args}"
        Rack::Handler::Thin.run Slanger::ApiServer, connection_args
        Slanger.debug "API server started"
      end

      def map_options_for_api_server(options)
        {Host: options[:api_host], Port: options[:api_port]}
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
    end
  end
end
