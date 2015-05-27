require 'spec_helper'
require 'slanger'

describe Slanger::Janitor::NodeStatus do
  let(:node_status) { Slanger::Janitor::NodeStatus.new }

  it "#online_ids" do
    expect(node_status.online_ids).to eq []
    redis.sadd "slanger-online-node-ids", 1
    expect(node_status.online_ids).to eq ["1"]
  end

  it "#mark_as_offline!" do
    redis.sadd "slanger-online-node-ids", 1
    redis.sadd "slanger-online-node-ids", 2
    node_status.mark_as_offline! 2
    expect(node_status.online_ids).to eq ["1"]
  end

  it "#mark_as_online!" do
    redis.sadd "slanger-online-node-ids", 1
    node_status.mark_as_online! 3
    expect(node_status.online_ids).to eq ["1", "3"]
  end

  let(:user_1) { {user_id: 123}.to_json }
  let(:user_2) { {user_id: 456}.to_json }


  context "with acknowledgements" do
    let(:acknowledgements) { [ {"online" => true, "type" => "response", "node_id" => 1}] }
    before do
      redis.sadd "slanger-online-node-ids", 1
      redis.sadd "slanger-online-node-ids", 2
      redis.hset "slanger-roster-presence-channel-node-1", "S1.1", 123
      redis.hset "slanger-roster-presence-channel-node-2", "S1.2", 123
    end

    it "#determining_missing_from_acknowledgements!" do
      missing, online = node_status.determine_missing_from_acknowledgements!(acknowledgements)

      expect(missing).to eq ["2"]
      expect(online).to eq ["1"]
    end

    it "#update_from_acknowledgements!" do
      node_status.update_from_acknowledgements!(acknowledgements)

      expect(redis.smembers "slanger-online-node-ids").not_to include "2"
      expect(redis.smembers "slanger-online-node-ids").not_to include 2
      expect(redis.keys).    to include "slanger-roster-presence-channel-node-1"
      expect(redis.keys).not_to include "slanger-roster-presence-channel-node-2"
    end
  end

  context "removing invalid users" do
    before do
      redis.sadd "slanger-online-node-ids", 1
      redis.sadd "slanger-online-node-ids", 2
      redis.sadd "slanger-roster-presence-abcd",  user_1
      redis.sadd "slanger-roster-presence-abcd",  user_2
      redis.hset "slanger-roster-presence-abcd-node-1",  "S1.4", 123
      redis.hset "slanger-roster-presence-abcd-node-2",  "S1.5", 123

      redis.sadd "slanger-roster-presence-defg",  user_1
      redis.sadd "slanger-roster-presence-defg",  user_2
      redis.hset "slanger-roster-presence-defg-node-1", "S1.1", 123
      redis.hset "slanger-roster-presence-defg-node-2", "S1.2", 123
      redis.hset "slanger-roster-presence-defg-node-2", "S1.3", 456
    end

    it do
      expect(redis.smembers "slanger-roster-presence-abcd").to eq [user_1, user_2]
      expect(redis.smembers "slanger-roster-presence-defg").to eq [user_1, user_2]
      node_status.remove_invalid_users!

      expect(redis.smembers "slanger-roster-presence-abcd").to eq [user_1]
      expect(redis.smembers "slanger-roster-presence-defg").to eq [user_1, user_2]
    end
  end

  context "removing presence keys" do
    before do
      redis.sadd "slanger-online-node-ids", 1
      redis.sadd "slanger-online-node-ids", 2

      redis.hset "slanger-roster-presence-channel-node-1", "S1.1", 123
      redis.hset "slanger-roster-presence-channel-node-2", "S1.2", 123
      redis.hset "slanger-roster-presence-channel-node-56", "S1.3", 123

    end

    it "#valid_presence_channel_key?!" do
      expect(node_status.valid_presence_channel_key?("slanger-roster-presence-channel-node-56")).to be_falsey
      expect(node_status.valid_presence_channel_key?("slanger-roster-presence-channel-node-1")).to be_truthy
    end

    it "#remove_invalid_presence_channels!" do
      node_status.remove_invalid_presence_channels!

      expect(redis.keys).to include     "slanger-roster-presence-channel-node-1"
      expect(redis.keys).to include     "slanger-roster-presence-channel-node-2"
      expect(redis.keys).not_to include "slanger-roster-presence-channel-node-56"
    end
  end

  def redis
    @redis ||= Slanger::Redis.sync_redis_connection
  end
end

