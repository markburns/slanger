require 'thin'
require 'rack'
require "logger"

#autoload logger
Slanger::Logger

module Slanger
  def self.node_id
    Service.node_id
  end

  module Service
    class << self
      attr_reader :websocket_server_signature

      def run(options={})
        EM.run do
          options = Slanger::Config.load options
          setup_logger!(options)
          Slanger.debug "Slanger::Service.run logging setup"

          Slanger::Config[:require].each { |f| require f }

          create_pid!
          fetch_node_id!
          start_api_server!
          start_websocket_server!
          set_online_status!
          trap_signals!
        end
      rescue Exception => e
        puts e
        puts e.backtrace.join "\n"
        stop
        remove_pid!
      end

      def setup_logger!(options)
        log_file  = options[:log_file]  || STDOUT.tap{|s| s.sync=true}
        log_level = options[:log_level] || ::Logger::INFO

        Slanger.logger = ::Logger.new log_file
        Slanger.log_level = log_level
      end


      def trap_signals!
        %w(INT HUP).each do |s|
          Signal.trap(s) {
            puts "Trapped signal #{s}"
            puts "Stopping slanger"
            Slanger::Service.stop
          }
        end
      end

      def stop
        if EM.reactor_running?
          EM.stop
        end
      ensure
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
        Slanger.debug "Setting node as online #{node_id}"
        Slanger::Redis.sync_redis_connection.sadd("slanger-online-node-ids", node_id)
      end

      def fetch_node_id
        Slanger::Redis.sync_redis_connection.hincrby("slanger-node", "next-id", 1)
      end

      def start_websocket_server!(options=Slanger::Config.options)
        ws_options = map_options_for_websocket_server(options)

        Slanger.info "WSS options: #{ws_options}"
        @websocket_server_signature = Slanger::WebSocketServer.run(ws_options)

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

      def start_api_server!(options=Slanger::Config.options)
        connection_args = map_options_for_api_server options 
        Thin::Logging.silent = false

        Slanger.info "Starting API server #{connection_args}"
        Rack::Handler::Thin.run Slanger::Api::Server, connection_args
        Slanger.debug "API server started"
      end

      def map_options_for_api_server(options)
        {Host: options[:api_host], Port: options[:api_port]}
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
