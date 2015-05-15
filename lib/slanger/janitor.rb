module Slanger
  module Janitor
    def request
      redis.publish("slanger:roll_call", "request")
    end

    def register_roll_call!
      pubsub.on(:message) do |channel, msg|
        Slanger.debug "Rollcall message received: #{msg}"
        if msg == "request"
          redis.publish("slanger:roll_call", {node_id: Slanger.node_id, pid: Process.pid}.to_json)
        else
          yield msg if block_given?
        end
      end
    end

    def pubsub
      @pubsub ||= begin
                    redis.pubsub.tap do |p|
                      p.subscribe('slanger:roll_call')
                    end
                  end
    end

    def redis
      @redis ||= EM::Hiredis.connect Slanger::Config.redis_address
    end

    extend self
  end
end
