require 'spec_helper'
require 'slanger'

describe Slanger::Presence::RosterRemoval do
  let(:roster) { Slanger::Presence::Roster.new channel_id }
  let(:channel_id) { "presence-abcd" }
  describe "#user_node_empty?" do
    #keys in redis
    #
    #
    #slanger-presence-abcd
    #{user_id: "U1", user_info: {name: "mark", surname: "burns"}} 
    #
    #hash:  slanger-presence-P1-node-N1
    #key:   S1
    #value: U1
    #

  end

  def set_internal(internal, user_mapping={})
    redis_roster = double "redis roster"
    expect(Slanger::RedisRoster).to receive(:new).and_return(redis_roster)
    expect(redis_roster).to receive(:internal_roster).and_return(internal)
    expect(redis_roster).to receive(:user_mapping).and_return(user_mapping)
  end

  describe "#user_in_roster?" do
    it "with an empty hash of users" do
      set_internal({})
      expect(roster.user_in_roster?(:U1)).to be false
    end

    it "with other present users" do
      set_internal({"N1" => {"S1" => :U2}})
      expect(roster.user_in_roster?(:U1)).to be false
    end

    it "with nodes and subscriptions" do
      set_internal({"N1" => {"S1" => :U1}})
      expect(roster.user_in_roster?(:U1)).to be true
    end
  end

  describe "#remove_internal" do
    let(:params) { Slanger::Presence::RosterParams.new channel_id, "N1", "S1" }
    let(:user_1) { {"user_id" => "U1"} }

    it "copes with an empty roster" do
      set_internal({})
      roster.remove_internal(params)
      expect(roster.internal_roster).to eq({})
    end

    it "removes from the internal roster" do
      internal = {"N1" => {"S1"=>user_1, "S2"=> user_2}}
      set_internal(internal)

      roster.remove_internal(params)
      expect(roster.internal_roster).to eq({"N1"=> {"S2" => user_2}})
    end
  end

  let(:redis) { ::Redis.new url: Slanger::Config.redis_address }
  let(:key) { "slanger-roster-presence-abcd" }
  let(:user_1) { {"user_id" => "U1"} }
  let(:user_2) { {"user_id" => "U2"} }

  def setup_test_data!
    internal_roster.each do |node, subscriptions|
      subscriptions.each do |s, user|
        redis.sadd key, user.to_json
      end

      subscriptions.each do |subscription_id, user|
        redis.hset "#{key}-node-#{node}", subscription_id, user["user_id"]
      end
    end
  end

  before do
    allow(Slanger::Service).to receive(:node_id).and_return "N1"
    allow(Slanger::Service).to receive(:present_node_ids).and_return ["N1", "N2", "N3"]
  end


  context "loading the roster" do
    before do
      setup_test_data!
    end

    let(:internal_roster) do
      {"N1" => {"S1" => user_1, "S3" => user_2},
       "N2" => {"S2" => user_1, "S4" => user_2, "S5" => user_1},
       "N3" => {"S7" => user_1, "S8" => user_2, "S9" => user_1}
      }
    end

    it do
      expect(roster.internal_roster).to eq internal_roster
    end
  end

  describe "#remove" do
    let(:internal_roster) do
      #N1 = node_id, S1, S2 etc = subscription_id
      {"N1" => {"S1" => user_1, "S2" => user_1},
       "N2" => {"S4" => user_1, "S5" => user_1, "S7" => user_2},
       "N3" => {"S3" => user_2, "S6" => user_2}
      }
    end
    before do
      setup_test_data!


      EM.run do
        roster.remove(node_to_delete_from, subscription_id_to_delete, &callback)
      end
    end

    after do
      #sanity check
      expect(roster.internal_roster).to eq Slanger::RedisRoster.new(channel_id).internal_roster
    end


    let(:callback) { ->{ EM.stop }}

    let(:subscription_id_to_delete) { "S1" }
    let(:node_to_delete_from) { "N1" }
    context "with the last subscription for this node" do
      let(:internal_roster) do
        {"N1" => {"S1" => user_1},
         "N2" => {"S2" => user_1}
        }
      end

      it "deletes the specific node entry" do
        expect(roster.internal_roster["N1"]).to be_nil
      end
    end

    context "with other subscriptions for this node" do
      let(:internal_roster) do
        {"N1" => {"S1" => user_1, "S2" => user_1} }
      end

      it "only deletes the specific subscription entry" do
        expect(roster.internal_roster["N1"]).to eq({"S2" => user_1})
      end
    end

    context "with no other nodes or subscriptions for this user" do
      let(:internal_roster) do
        {"N1" => {"S1" => user_1},
         "N2" => {"S2" => user_2}
        }
      end

      it "deletes from the main presence-channel hash" do
        expect(roster.internal_roster).to eq({ "N2" => {"S2" => user_2} })
      end

      it "removes the user from the redis presence-channel key" do
        expect(redis.keys).to_not include("#{key}-node-N1")

        expect(redis.smembers(key)).to eq [user_2.to_json]
      end

      it "sends a notification" do
      end
    end
  end
end
