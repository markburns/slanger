require 'spec_helper'
require 'slanger'

describe 'Slanger::Roster' do
  let(:roster) { Slanger::Presence::Roster.new channel_id }
  let(:channel_id) { "presence-abcd" }

  before do
    allow(Slanger).to receive(:node_id).and_return "node-1"
    redis_roster = double "redis roster", fetch: internal_roster
    expect(Slanger::RedisRoster).to receive(:new).and_return redis_roster
  end

  let(:user_1) { {"user_id" => "1", "user_info" => {}} }
  let(:user_2) { {"user_id" => "2", "user_info" => {"something" =>"here"}} }

  let(:subscriptions_1) do
    { "node-1" => ["subscription-1"],
      "node-2" => ["subscription-2"] }
  end

  let(:subscriptions_2) do
    {
      "node-2" => ["subscription-3"],
      "node-3" => ["subscription-4", "subscription-5"]
    }
  end

  let(:internal_roster) { {user_1 => subscriptions_1, user_2 => subscriptions_2} }

  it "#present?" do
    expect(roster.present?(user_1)).to eq true
    expect(roster.present?(user_2)).to eq true
    expect(roster.present?({"not" => "here"})).to eq false
  end

  it "#subscribers" do
    expect(roster.subscribers).to eq({"1" => {}, "2" => {"something" => "here"}})
  end

  it "#subscribers_count" do
    expect(roster.subscribers_count).to eq(2)
  end

  it "#ids" do
    expect(roster.ids).to eq ["1", "2"]
  end
end


