require 'spec_helper'
require 'slanger'

describe 'Slanger::Roster' do
  let(:roster) { Slanger::Presence::Roster.new channel_id }
  let(:channel_id) { "presence-abcd" }

  before do
    expect(Slanger::Redis).to receive(:hgetall_sync).
      with(channel_id).
      and_return([
        user_1.to_s,
        subscriptions_1.to_s,
        user_2.to_s,
        subscriptions_2.to_s,
      ])
  end

  let(:user_1) { {"user_id" => "1", "user_info" => {}} }
  let(:user_2) { {"user_id" => "2", "user_info" => {"something" =>"here"}} }

  let(:subscriptions_1) do
    { "node:1" => ["subscription:socket-1"],
      "node:2" => ["subscription:socket-2"] }
  end

  let(:subscriptions_2) do
    { "node:3" => ["subscription:socket-3", "subscription:socket-4"],
      "node:2" => ["subscription:socket-5"] }
  end

  it "#internal_roster" do
    expected = {user_1 => subscriptions_1, user_2 => subscriptions_2}

    expect(roster.internal_roster).to eq expected
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

  it "#redis_to_hash" do
    result = roster.redis_to_hash ["1", "2", "\"a\"", "{}"]

    expect(result).to eq({1 => 2,"a"  => {}})
  end
end


