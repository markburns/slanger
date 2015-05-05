require 'spec_helper'
require 'slanger'
require 'rspec-mocks'

describe 'Slanger::Roster' do
  let(:roster) { Slanger::Roster.new 'presence-channel' }

  context "success case" do
    before do
      RSpec.configure do |c|
        c.mock_framework = :rspec
      end
      Slanger::Redis.expects(:hgetall).returns redis
    end



    let(:redis) { double("redis", callback: callback)}
    let(:callback) { ->(success){ success.call(result); chain } }
    let(:result) { [] }
    let(:chain) { mock("chain", errback: ->(e){ }) }
    it do
      roster.fetch

      expect(roster.internal_roster).to eq {}
    end

  end
end


