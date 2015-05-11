require 'spec_helper'
require 'slanger'

describe 'Slanger::Roster' do
  let(:roster) { Slanger::Presence::Roster.new 'presence-channel' }

  it "#redis_to_hash" do
    result = roster.redis_to_hash ["1", "2", "\"a\"", "{}"]

    expect(result).to eq({1 => 2,"a"  => {}})
  end

  it do
    user_1 = {"user_id" => "1", "user_info" => {}}

    expected = {
      user_1 => {
        "node:1" => ["subscription:abc"],
        "node:2" => ["subscription:def"]
      }
    }

    expect(Slanger::Redis).to receive(:hgetall_sync).
      with("presence-channel").
      and_return([
        "{\"user_id\"=>\"1\", \"user_info\"=>{}}",
        "{\"node:1\"=>[\"subscription:abc\"], \"node:2\"=>[\"subscription:def\"]}"
      ])

    expect(roster.internal_roster).to eq expected
  end

end


