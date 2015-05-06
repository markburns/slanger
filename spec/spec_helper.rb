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
require 'slanger'

require "redis"

WebMock.disable!

module Slanger; end
Slanger::Logger

require "byebug"
require "pry-byebug"

#require 'pretty_backtrace'
#PrettyBacktrace.enable


RSpec.configure do |config|
  config.formatter = 'documentation'
  config.color = true
  config.mock_framework = :rspec
  config.order = 'random'
  config.include SlangerHelperMethods
  config.fail_fast = true
  config.after(:each) { stop_slanger if server_pids.any? }
  config.around(:each) {|e| 
    if ENV["SKIP_TIMEOUT"]
      e.run 
    else
      Timeout.timeout 1 do
        e.run
      end
    end

  }
  config.before :all do
    redis = Redis.new

    redis.keys("*").each do |k|
      Slanger.debug "deleting #{k}"
      redis.del k
    end

    Pusher.tap do |p|
      p.host   = '0.0.0.0'
      p.port   = 4567
      p.app_id = 'your-pusher-app-id'
      p.secret = 'your-pusher-secret'
      p.key    = '765ec374ae0a69f4ce44'
    end
  end
end
