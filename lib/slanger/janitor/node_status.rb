module Slanger
  module Janitor
    class NodeStatus
      include SyncRedis

      def online_ids
        redis.smembers "slanger-online-node-ids"
      end

      def previously_online_ids
        @previously_online_ids ||= online_ids
      end

      def mark_as_offline!(*ids)
        ids.each do |id|
          Slanger.error "Slanger node: #{id} is down, removing from roster"
          redis.srem "slanger-online-node-ids", id
        end
      end

      def mark_as_online!(*ids)
        ids.each do |id|
          redis.sadd "slanger-online-node-ids", id
        end
      end

      def update_from_acknowledgements!(acknowledgements)
        missing = determining_missing_from_acknowledgements!(acknowledgements)

        mark_as_offline!(*missing)
        remove_invalid_presence_channels!
        missing
      end

      def determining_missing_from_acknowledgements!(acknowledgements)
        online_ids = acknowledgements.select{|a| a["online"] }.map do |a|
          a["node_id"].to_s
        end

        missing_ids, @previously_online_ids = (previously_online_ids - online_ids), online_ids

        missing_ids
      end

      def remove_invalid_presence_channels!
        valid_ids = online_ids

        redis.keys("slanger-roster-*-node-*").each do |k|
          unless valid_presence_channel_key?(k)
            Slanger.error "Deleting presence channel info: #{k}"
            redis.del k
          end
        end
      end

      def valid_presence_channel_key?(key)
        match = key.match /\Aslanger-roster-.*-node-(\d+)\z/

        online_ids.include?(match[1])
      rescue
        false
      end

    end
  end
end
