require 'spec_helper'
require 'slanger'

describe 'Slanger::Roster' do
  let(:roster) { Slanger::Presence::Roster.new channel_id }
  let(:channel_id) { "presence-abcd" }


  before do
    redis_roster = double "redis roster"
    allow(Slanger::RedisRoster).to receive(:new).and_return(redis_roster)
    allow(redis_roster).to receive(:internal_roster).and_return(internal_roster)
    allow(redis_roster).to receive(:user_mapping).and_return(user_mapping)
    allow(Slanger).to receive(:node_id).and_return "N1"
  end

  let(:user_1) { {"user_id" => "U1", "user_info" => {}} }
  let(:user_2) { {"user_id" => "U2", "user_info" => {"something" =>"here"}} }

  let(:subscriptions_1) do
    { "N1" => ["S1"],
      "N2" => ["S2"] }
  end

  let(:subscriptions_2) do
    {
      "N2" => ["S3"],
      "N3" => ["S4", "S5"]
    }
  end

  let(:internal_roster) { {user_1 => subscriptions_1, user_2 => subscriptions_2} }
  let(:user_mapping)do
    {"U1"=>{}, "U2"=> {"something" => "here"}}
  end

  it "#present?" do
    expect(roster.present?(user_1)).to eq true
    expect(roster.present?(user_2)).to eq true
    expect(roster.present?({"not" => "here"})).to eq false
  end

  it "#subscribers" do
    expect(roster.subscribers).to eq({"U1" => {}, "U2" => {"something" => "here"}})
  end

  it "#subscribers_count" do
    expect(roster.subscribers_count).to eq(2)
  end

  it "#ids" do
    expect(roster.ids).to eq ["U1", "U2"]
  end
end


