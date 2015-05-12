require 'spec_helper'
require 'slanger'

describe Slanger::Presence::RosterRemoval do
  let(:roster) { Slanger::Presence::Roster.new channel_id }
  let(:channel_id) { "presence-abcd" }
  describe "#user_node_empty?" do
    it "with an empty hash of users" do
      expect(roster.remove_user_node?({}, :U1, "N1")).to be nil
    end

    it "with a key but an empty hash of node info" do
      expect(roster.remove_user_node?({:U1 => {}}, :U1, "N1")).to be nil
    end

    it "with nodes, but empty subscriptions" do
      expect(roster.remove_user_node?({:U1 => {"N1" => []}}, :U1, "N1")).to be true
    end

    it "with nodes and subscriptions" do
      expect(roster.remove_user_node?({:U1 => {"N1" => ["S1"]}}, :U1, "N1")).to be false
    end

    it "with a missing user" do
      expect(roster.remove_user_node?({:U2 => {"N1" => ["S1"]}}, :U1, "N1")).to be nil
    end
  end

  describe "#user_empty?" do
    it "with an empty hash of users" do
      expect(roster.remove_user?({}, :U1)).to be false
    end

    it "with a key but an empty hash of node info" do
      expect(roster.remove_user?({:U1 => {}}, :U1)).to be true
    end

    it "skips nodes with empty subscriptions" do
      expect(roster.remove_user?({:U1 => {"N1" => []}}, :U1)).to be false
    end

    it "with nodes and subscriptions" do
      expect(roster.remove_user?({:U1 => {"N1" => ["S1"]}}, :U1)).to be false
    end

    it "skips missing users" do
      expect(roster.remove_user?({:U2 => {"N1" => ["S1"]}}, :U1)).to be false
    end
  end

  describe "#remove_internal" do
    let(:params) { Slanger::Presence::Roster::Params.new channel_id, "N1", user_1, "S1" }
    let(:user_1) { {"user_id" => "U1"} }

    it "copes with an empty roster" do
      roster.remove_internal(params, {})
      expect(roster.internal_roster).to eq({})
    end

    it "removes" do
      result = roster.remove_internal(params, {user_1 => {"N1" => ["S1", "S2"], "N2" => ["S3"]}})
      expect(result).to eq({user_1 => {"N1" => ["S2"],       "N2" => ["S3"]}})
    end
  end

  describe "#remove" do
    before do
      allow(Slanger::Service).to receive(:node_id).and_return "N1"
      allow(Slanger::Service).to receive(:present_node_ids).and_return ["N1", "N2"]
    end

    let(:internal_roster) do
      { user_1=> user_1_subscriptions, user_2=> user_2_subscriptions, }
    end

    #N1 = node_id, S1, S2 etc = subscription_id
    let(:user_1_subscriptions) { { "N1"=>["S1", "S2"], "N2"=>["S4", "S5"]} }
    let(:user_2_subscriptions) { { "N3"=>["S3", "S4"], "N2"=>["S6"]} }

    let(:user_1) { {"user_id" => "U1"} }
    let(:user_2) { {"user_id" => "U2"} }

    let(:redis) { ::Redis.new url: Slanger::Config.redis_address }
    let(:key) { "slanger-roster-presence-abcd" }

    before do
      internal_roster.each do |user, nodes|
        redis.sadd key, user
        nodes.each do |node, subscriptions|
          redis.sadd "#{key}-user-#{user["user_id"]}-node-#{node}", subscriptions
        end
      end

      EM.run do
        roster.remove(node_to_delete_from, user_1, subscription_id_to_delete, &callback)
      end
    end

    after do
      #sanity check
      expect(roster.internal_roster).to eq Slanger::RedisRoster.fetch(channel_id)
    end


    let(:callback) { ->{ EM.stop }}

    let(:subscription_id_to_delete) { "S1" }
    let(:node_to_delete_from) { "N1" }

    context "with the last subscription for this node" do
      let(:user_1_subscriptions) { { "N1"=>["S1"], "N2"=>["S2"]} }

      it "deletes the specific node entry" do
        expect(roster.internal_roster[user_1]["N1"]).to be_nil
      end
    end

    context "with other subscriptions for this node" do
      let(:user_1_subscriptions) { { "N1"=>["S1", "S2"]} }

      it "only deletes the specific subscription entry" do
        expect(roster.internal_roster[user_1]["N1"]).to eq ["S2"]
      end
    end

    context "with no other nodes or subscriptions" do
      let(:user_1_subscriptions){{"N1" => ["S1"]}}
      let(:user_2_subscriptions){{"N1" => ["S3"], "N2" => ["S6"]}}

      let(:subscription_id_to_delete) { "S1" }
      let(:node_to_delete_from) { "N1" }

      it "deletes from the main presence-channel hash" do
        expect(roster.internal_roster[user_1]).to eq nil
      end

      it "removes the user from the redis presence-channel key" do
        expect(redis.keys).to_not include("#{key}-user-U1-node-N1")

        expect(redis.smembers(key)).to eq [user_2.to_s]
      end

      it "sends a notification" do
      end
    end
  end
end
