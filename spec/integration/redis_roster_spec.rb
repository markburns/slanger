require 'spec_helper'

describe Slanger::RedisRoster do
  describe "#fetch"do
    let(:redis_roster) { Slanger::RedisRoster.new channel_id }
    let(:channel_id) { "presence-abcd" }
    let(:user_1) { {"user_id" => "U1", "user_info" => {}} }
    let(:user_2) { {"user_id" => "U2", "user_info" => {"something" =>"here"}} }


    before do
      expect(Slanger::Service).to receive(:present_node_ids).and_return ["N1", "N2"]
      redis = ::Redis.new url: Slanger::Config.redis_address

      key = "slanger-roster-presence-abcd"
      redis.sadd key, [user_1.to_json, user_2.to_json]

      redis.hset "#{key}-node-N1", "S1", "U1"
      redis.hset "#{key}-node-N1", "S3", "U2"
      redis.hset "#{key}-node-N2", "S4", "U1"
    end

    it do
      result = redis_roster.fetch


      expect(result).to eq ({
        "N1"=>{"S1"=>user_1, "S3"=>user_2},
        "N2"=>{"S4" =>user_1}
      }
      )
    end
  end
end

