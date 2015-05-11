require 'spec_helper'

describe Slanger::RedisRoster do
  describe "#fetch"do
    let(:redis_roster) { Slanger::RedisRoster.new channel_id }
    let(:channel_id) { "presence-abcd" }
    let(:user_1) { {"user_id" => "1", "user_info" => {}} }
    let(:user_2) { {"user_id" => "2", "user_info" => {"something" =>"here"}} }


    before do
      expect(Slanger::Service).to receive(:present_node_ids).and_return ["1", "2"]
      redis = ::Redis.new url: Slanger::Config.redis_address

      key = "slanger-roster-presence-abcd"
      redis.sadd key, [user_1, user_2]

      redis.sadd "#{key}-node-1-user-1", ["subscription-1", "subscription-2"]
      redis.sadd "#{key}-node-1-user-2", ["subscription-3"]
      redis.sadd "#{key}-node-2-user-1", ["subscription-4", "subscription-5"]
      redis.sadd "#{key}-node-2-user-2", ["subscription-6"]
    end

    it do
      result = redis_roster.fetch

      expected_1 = {"1"=>["subscription-2", "subscription-1"], "2"=>["subscription-5", "subscription-4"]}
      expect(result[user_1]).to eq expected_1

      expected_2 = {"1"=>["subscription-3"], "2"=>["subscription-6"]}
      expect(result[user_2]).to eq expected_2
    end
  end
end

