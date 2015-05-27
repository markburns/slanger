module Slanger
  module Janitor
    class NodeStatus
      include Slanger::SyncRedis

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
        missing, online = determine_missing_from_acknowledgements!(acknowledgements)

        mark_as_online!(*online)
        mark_as_offline!(*missing)
        remove_invalid_presence_channels!
        remove_invalid_users!
        missing
      end

      def determine_missing_from_acknowledgements!(acknowledgements)
        online_ids = acknowledgements.select{|a| a["online"] }.map do |a|
          a["node_id"].to_s
        end

        missing_ids, @previously_online_ids = (previously_online_ids - online_ids), online_ids

        [missing_ids, online_ids]
      end

      def remove_invalid_users!
        valid_ids = online_ids
        shown_as_present = {}
        actually_present_ids = {}


        redis.keys("slanger-roster-presence-*").each do |k|
          if k !~ /-node-\d+\z/
            shown_as_present[k] = redis.smembers k
          else
            channel_key = k.gsub /-node-\d+\Z/, ""
            actually_present_ids[channel_key] ||= []
            actually_present_ids[channel_key] += redis.hvals(k)
          end
        end

        actually_present_users = {}

        actually_present_ids.each do |key, ids|
          users = Array(shown_as_present[key]).select do |u| 
            ids.uniq.map(&:to_s).include?(JSON.parse(u)["user_id"].to_s)
          end

          actually_present_users[key]=users if users.any?
        end

        actually_present_users.each do |key, users|
          redis.del key
          redis.sadd key, users
        end

        shown_as_present.each do |k, users|
          missing = Array(users) - Array(actually_present_users[k])

          missing.each do |m|
            redis.srem k, m
          end
        end
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

