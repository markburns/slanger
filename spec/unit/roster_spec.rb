require 'spec_helper'
require 'slanger'

describe 'Slanger::Roster' do
  let(:roster) { Slanger::Presence::Roster.new 'presence-channel' }

  it "#redis_to_hash" do
    result = roster.redis_to_hash ["1", "2", "\"a\"", "{}"]

    expect(result).to eq({1 => 2,"a"  => {}})
  end

  before do
    expect(Slanger::Redis).to receive(:hgetall_sync).
      with("presence-channel").
      and_return([
        user_1.to_s,
        subscriptions.to_s
      ])
  end

  let(:user_1) { {"user_id" => "1", "user_info" => {}} }
  let(:subscriptions) do
    { "node:1" => ["subscription:abc"],
      "node:2" => ["subscription:def"] } 
  end
  it do
    expected = {user_1 => subscriptions}

    expect(roster.internal_roster).to eq expected
  end

end


