module Slanger
  module Janitor
    module Node
      extend self
      extend Slanger::SyncRedis

      def subscribe
        Slanger::Janitor.subscribe_to_roll_call("request") do |msg|
          respond
        end
        Slanger::Janitor.subscribe_to_roll_call("update") do |msg|
          update(msg)
        end
      end

      def respond
        reply = {node_id: Slanger.node_id, pid: Process.pid, online: true}

        redis.publish("slanger:roll_call:response", reply.to_json)
      end

      def update(msg)

        Presence::Channel.remove_invalid_nodes!(msg["online_node_ids"])
      end
    end
  end
end
