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

  context "with acknowledgements" do
    let(:acknowledgements) { [ {"online" => true, "type" => "response", "node_id" => 1}] }
    before do
      redis.sadd "slanger-online-node-ids", 1
      redis.sadd "slanger-online-node-ids", 2
      redis.sadd "slanger-roster-presence-channel-node-1",  {user_id: 123}.to_json
      redis.sadd "slanger-roster-presence-channel-node-2",  {user_id: 123}.to_json
    end

    it "#determining_missing_from_acknowledgements!" do
      result = node_status.determining_missing_from_acknowledgements!(acknowledgements)

      expect(result).to eq ["2"]
    end

    it "#update_from_acknowledgements!" do
      node_status.update_from_acknowledgements!(acknowledgements)

      expect(redis.smembers "slanger-online-node-ids").not_to include "2"
      expect(redis.smembers "slanger-online-node-ids").not_to include 2
      expect(redis.keys).    to include "slanger-roster-presence-channel-node-1"
      expect(redis.keys).not_to include "slanger-roster-presence-channel-node-2"
    end
  end


  context "removing presence keys" do
    before do
      redis.sadd "slanger-online-node-ids", 1
      redis.sadd "slanger-online-node-ids", 2
      redis.sadd "slanger-roster-presence-channel-node-1",  {user_id: 123}.to_json
      redis.sadd "slanger-roster-presence-channel-node-2",  {user_id: 123}.to_json
      redis.sadd "slanger-roster-presence-channel-node-56", {user_id: 123}.to_json
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

