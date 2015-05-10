require 'spec_helper'
require 'slanger'

describe 'Slanger::Roster' do
  let(:roster) { Slanger::Presence::Roster.new 'presence-channel' }

  it "#redis_to_hash" do
    expect(Slanger::Redis).to receive(:hgetall_sync).and_return [1,"2"]


    expect(roster.internal_roster).to eq({1 => 2})
  end

end


