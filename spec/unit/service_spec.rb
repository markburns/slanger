require 'spec_helper'

describe Slanger::Service do
  describe "#fetch_node_id!"do
    pending do
      redis = double "redis"
      expect(Slanger::Redis).to receive(:sync_redis_connection).and_return redis

      expect(redis).to receive(:hincrby).
        with("slanger-node", "next-id", 1).
        and_return 1

      Slanger::Service.fetch_node_id!
      expect(Slanger.node_id).to eq 1
    end
  end

end
