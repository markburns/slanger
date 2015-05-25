# encoding: utf-8
require 'sinatra/base'
require 'signature'
require 'json'
require 'active_support/core_ext/hash'
require 'eventmachine'
require 'em-hiredis'
require 'rack'
require 'fiber'
require 'rack/fiber_pool'

module Slanger
  module Api
    class Server < Sinatra::Base
      use Rack::FiberPool
      set :raise_errors, lambda { true }
      set :show_exceptions, true

      error(Signature::AuthenticationError) { |e| halt 401, "401 UNAUTHORIZED" }
      error(Slanger::Api::InvalidRequest)   { |c| halt 400, "400 Bad Request" }

      before do
        #skip healthcheck / 404 page etc
        if env["PATH_INFO"] =~ /\Aapps/
          valid_request
          status 202
        end
      end

      if ENV["DEBUGGER"]
        get '/slanger/roster/:channel_id' do
          channel_id = params[:channel_id]
          raise Slanger::InvalidRequest.new "invalid channel_id" unless channel_id =~ /\Apresence-[a-zA-Z_\-]+\z/

          channel = Slanger::Channel.from(channel_id)
          r = channel.send(:roster)
          [r.internal_roster, r.user_mapping].to_json
        end
      end

      post '/apps/:app_id/events' do
        valid_request.tap do |r|
          EventPublisher.publish(r.channels,
                                 r.body["name"],
                                 r.body["data"],
                                 r.socket_id)
        end

        {}.to_json
      end

      post '/apps/:app_id/channels/:channel_id/events' do
        valid_request.tap do |r|
          EventPublisher.publish(r.channels,
                                 r.params["name"],
                                 r.body,
                                 r.socket_id)
        end

        {}.to_json
      end

      def valid_request
        @valid_request ||=
          begin
            request_body ||= request.body.read.tap{|s| s.force_encoding("utf-8")}
            RequestValidation.new(request_body, params, env["PATH_INFO"])
          end
      end
    end
  end
end
