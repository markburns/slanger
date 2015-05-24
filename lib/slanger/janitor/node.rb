module Slanger
  module Janitor
    module Node
      extend self
      extend Slanger::SyncRedis

      def subscribe
        Slanger::Janitor.subscribe_to_roll_call do |msg|
          handle msg
        end
      end

      def handle(msg)
        Slanger.debug "Node:#{Slanger.node_id} Rollcall message received: #{msg}"

        case msg["type"] 
        when "request"
          respond
        end
      end

      def respond
        reply = {node_id: Slanger.node_id, pid: Process.pid, online: true, type: "response"}

        redis.publish("slanger:roll_call", reply.to_json)
      end
    end
  end
end 
