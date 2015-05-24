require 'spec_helper'
require 'slanger'

describe Slanger::Presence::RosterAddition do
  let(:roster) { Slanger::Presence::Roster.new channel_id }
  let(:channel_id) { "presence-abcd" }

  before do
    allow(Slanger).to receive(:node_id).and_return "N1"
    allow(Slanger::Service).to receive(:present_node_ids).and_return ["N1", "N2", "N3"]

  end

  let(:user_1) { {"user_id" => "U1", "user_info" => {}} }
  let(:user_2) { {"user_id" => "U2", "user_info" => {"something" =>"here"}} }

  describe "#add" do
    let(:redis) { Redis.new }
    let(:key) { "slanger-roster-presence-abcd" }

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
      setup_test_data!
    end

    let(:internal_roster) do
      #N1 = node_id, S1, S2 etc = subscription_id
      {"N1" => {"S2" => user_1},
       "N2" => {"S4" => user_1, "S5" => user_1, "S7" => user_2},
       "N3" => {"S3" => user_2, "S6" => user_2}
      }
    end

    let(:callback) { ->(*a){ EM.stop }}

    context do
      before do
        em do
          roster.add("N1", "S1", user_1, callback)
        end
      end

      it "adds values to the internal roster" do
        expect(roster.internal_roster["N1"]["S1"]).to eq "U1"
      end

      it "adds to redis" do
        expect(redis.smembers key).to contain_exactly user_1.to_json, user_2.to_json
      end
    end

    context "updating the user_mapping" do
      context "when adding" do
        let(:user_mapping) do
          {"U1" => {}}
        end

        let(:internal_roster) do
          {"N1" => {"S1" => user_1}}
        end

        it "doesn't change if user already present" do
          em do
            roster.add("N2", "S2", user_1, callback)
          end

          expect(roster.user_mapping).to eq user_mapping
        end

        it "adds to the mapping change if user not present" do
          em do
            roster.add("N2", "S2", user_2, callback)
          end

          expect(roster.user_mapping).to eq({"U1" => {}, "U2" => {"something" => "here"}})
        end
      end

      context "when removing" do
        let(:user_mapping) do
          {"U1" => {}}
        end

        let(:internal_roster) do
          {"N1" => {"S1" => user_1}}
        end

        it "doesn't change if user not present" do
          em do
            roster.remove("N2", "S2", &callback)
          end

          expect(roster.user_mapping).to eq user_mapping
        end

        it "remove from the mapping if user is present" do
          em 0.4 do
            roster.remove("N1", "S1", &callback)
          end

          expect(roster.user_mapping).to eq({})
        end
      end
    end

    context "user is already present somewhere in the roster" do
      let(:internal_roster) do
        {"N2" => {"S2" => user_1}}
      end

      it "doesn't call the block" do
        em do
          roster.add("N1", "S1", user_1, callback) do |value|
            @was_called = true
          end
        end

        expect(@was_called).to eq nil
      end
    end

    context "user is not present" do
      let(:internal_roster) do
        {}
      end

      it "yields true to the block (i.e. not added)" do
        em do
          roster.add("N1", "S1", user_1, callback) do |value|
            @was_called = true
            expect(value).to be true
          end
        end

        expect(@was_called).to eq true
      end
    end

  end

end


