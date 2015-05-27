require "json"

module Slanger
  module Janitor
    def run(interval=1)
      setup!(interval) do
        EM.add_periodic_timer(interval) do
          Slanger.debug "Sending rollcall request"
          request!
        end
      end
    end

    def acknowledgements
      @acknowledgements
    end

    def request!
      @waiting_for_responses = true
      redis.publish("slanger:roll_call:request", {type: "request"}.to_json)
      Slanger.debug "#{self} Sent, waiting for responses..."
    end

    def setup!(interval)
      Slanger.debug "#{self} setup!"
      return if @setup

      @acknowledgements = []

      @node_status = Slanger::Janitor::NodeStatus.new

      Slanger.info "Initially online nodes: #{@node_status.previously_online_ids}"


      subscribe_to_roll_call("response") do |msg|
        Slanger.debug "Response received #{msg}"
        @acknowledgements << msg
      end

      yield if block_given?

      #give time after the initial rollcall request has been sent
      EM.add_timer interval + 2 do
        setup_response_monitoring(interval)
      end

      @setup = true
    end

    def setup_response_monitoring(interval)
      EM.add_periodic_timer interval do
        Slanger.debug "#{self} checking for responses"

        monitor_responses if @waiting_for_responses
      end
    end

    def monitor_responses
      Slanger.debug "Determining online node ids from responses: #{@acknowledgements}"
      Slanger.debug "Previously online: #{@node_status.previously_online_ids}"

      missing_ids = @node_status.update_from_acknowledgements!(@acknowledgements)
      @acknowledgements.clear

      if missing_ids.none?
        Slanger.info "Online nodes: #{@node_status.online_ids}"
      end

      message = {
        message: "Slanger online node ids updated",
        online_node_ids: Slanger::Service.present_node_ids
      }.to_json

      redis.publish("slanger:roll_call:update", message)
      @waiting_for_responses = false
    end

    def subscribe_to_roll_call(type)
      pubsub(type).on(:message) do |channel, msg|
        yield JSON.parse msg
      end
    end

    private

    def pubsub(type)
      redis.pubsub.tap do |p|
        p.subscribe("slanger:roll_call:#{type}")
      end
    end

    def redis
      EM::Hiredis.connect Slanger::Config.redis_address
    end

    extend self
  end
end
