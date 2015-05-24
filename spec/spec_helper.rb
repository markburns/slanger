require 'bundler/setup'

require 'active_support/json'
require 'active_support/core_ext/hash'
require 'eventmachine'
require 'em-http-request'
require 'pusher'
require 'thin'
require 'slanger_helper_methods'
require 'have_attributes'
require 'openssl'
require 'socket'
require 'timecop'
require 'pry'
require 'webmock/rspec'
require 'httparty'

require 'slanger'


WebMock.disable!

module Slanger; end
Slanger::Logger

require "byebug"
require "pry-byebug"
require 'binding_of_caller'


#require 'pretty_backtrace'
#PrettyBacktrace.enable


RSpec.configure do |config|
  config.formatter = 'documentation'
  config.color = true
  config.mock_framework = :rspec
  config.order = 'random'
  config.include SlangerHelperMethods
  config.fail_fast = false
  config.raise_errors_for_deprecations!

  config.around(:each) {|e|
    begin
      redis = Redis.new

      keys = redis.keys("*")
      Slanger.debug "deleting #{keys}"

      keys.each do |k|
        redis.del k
      end

      def remove_klass_ivs(object)
        return unless object.is_a?(Module)

        object.instance_eval do
          instance_variables.each do |iv|
            instance_variable_set iv, nil
          end
        end

        if object.respond_to?(:constants)
          constants = object.
            constants.
            map{|c| object.const_get(c) rescue nil}.
            compact.
            select{|c| c.is_a?(Module)}

          constants.each do |k|
            unless k.ancestors.include?(Struct)
              remove_klass_ivs(k)
            end
          end
        end
      end

      remove_klass_ivs(Slanger)

      e.run


    ensure
      stop_slanger if server_pids.any?
    end

  }
  config.before :all do


    Pusher.tap do |p|
      p.host   = '0.0.0.0'
      p.port   = 4567
      p.app_id = 'your-pusher-app-id'
      p.secret = 'your-pusher-secret'
      p.key    = '765ec374ae0a69f4ce44'
    end
  end
end
