require 'spec_helper'
require 'slanger'

describe 'Slanger::Roster' do
  let(:roster) { Slanger::Roster.new 'presence-channel' }
  let(:redis) { double "redis" }

  context "success case" do
    it do
      expect(Slanger::Redis).to receive(:hgetall).
        and_return(redis)

      something = double "something", errback: nil

      expect(redis).to receive(:callback).
        and_yield([1,"2"]).
        and_return something


        roster.fetch

        if roster.complete?
          expect(roster.internal_roster).to eq({1 => 2})
        end
    end

  end
end

