module Slanger
  module Janitor
    def request!
      redis.publish("slanger:roll_call", {type: "request"}.to_json)

      acknowledgements = []

      previously_online = Slanger::Service.present_node_ids

      register_roll_call!(silent_listener: true) do |msg|
        acknowledgements << msg unless msg["type"]=="request"

        EM.add_timer 0.5 do
          online_ids = acknowledgements.select{|a| a["online"] }.map do |a|
            a["node_id"].to_s
          end

          missing_ids = previously_online - online_ids

          if missing_ids.any?
            Slanger::Redis.sync_redis_connection.srem("slanger-online-node-ids", *missing_ids)
          end

          message = {type: "update", message:"Slanger online node ids updated: #{Slanger::Service.present_node_ids}"}
          em_channel.push(message)
        end
      end
    end

    def em_channel
      @em_channel ||= EM::Channel.new
    end

    def register_roll_call!(silent_listener: false, &blk)
      pubsub.on(:message) do |channel, msg|
        msg = JSON.parse msg

        if silent_listener
          yield msg
        else
          handle channel, msg, &blk
        end
      end
    end

    def handle(channel, msg, &blk)
      Slanger.debug "Node:#{Slanger.node_id} Rollcall message received: #{msg}"

      if msg["type"] == "request"
        respond
      else
        blk.call msg if blk
      end
    end

    def respond
      reply = {node_id: Slanger.node_id, pid: Process.pid, online: true}

      redis.publish("slanger:roll_call", reply.to_json)
    end

    private

    def pubsub
      redis.pubsub.tap do |p|
        p.subscribe('slanger:roll_call')
      end
    end

    def redis
      EM::Hiredis.connect Slanger::Config.redis_address
    end

    extend self
  end
end
