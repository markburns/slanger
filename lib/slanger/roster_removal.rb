module Slanger
  module RosterRemoval
    def remove(key, &blk)
      Slanger.debug "removing from redis #{key}"

      Slanger::Redis.hdel(channel_id, key).
        callback(&removal_success(key, &blk)).
        errback(&removal_error(key))
    end

    private

    def removal_success(key, &blk)
      Proc.new do
        with_roster do |r|
          r.delete key
          Slanger.debug "roster_remove successful channel_id: #{channel_id} key: #{key} internal_roster: #{@internal_roster}"
          blk.call
        end
      end
    end

    def removal_error(key)
      Proc.new do |e|
        Slanger.error "roster_remove failed #{e} channel_id: #{channel_id} key: #{key} internal_roster: #{@internal_roster}"
      end
    end
  end
end
