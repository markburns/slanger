require 'spec_helper'
require 'slanger'

describe Slanger::Presence::RosterAddition do
  let(:roster) { Slanger::Presence::Roster.new channel_id }
  let(:channel_id) { "presence-abcd" }

  before do
    allow(Slanger).to receive(:node_id).and_return "node-1"

    #smembers presence-abcd  => [{user-1}, {user-2}, ...]
    allow(Slanger::Redis).to receive(:smembers).
      with(channel_id).
      and_return([
        user_1.to_s,
        user_2.to_s,
      ])
  end

  let(:user_1) { {"user_id" => "1", "user_info" => {}} }
  let(:user_2) { {"user_id" => "2", "user_info" => {"something" =>"here"}} }

  let(:subscriptions_1) do
    { "node-1" => ["subscription-1"],
      "node-2" => ["subscription-2"] }
  end

  let(:subscriptions_2) do
    { "node-3" => ["subscription-3", "subscription-4"],
      "node-2" => ["subscription-5"] }
  end

  {{"user_id"=>"1", "user_info"=>{}}=>{
    "node-1"=>["subscription-1"],
    "node-2"=>["subscription-2"]},

  {"user_id"=>"2", "user_info"=>{"something"=>"here"}}=>{
    "node-3"=>["subscription-3", "subscription-4"],
    "node-2"=>["subscription-5"]}}

  describe "#add" do
    before do
      deferrable = double "deferrable", errback: nil
      allow(Slanger::Redis).to receive(:sadd).and_return deferrable
      allow(deferrable).to receive(:callback).and_yield(1).and_return deferrable
    end
    let(:callback) { double "callback", call: nil }

    it "calls the callback" do
      expect(callback).to receive :call
      roster.add("subscription-1234", user_1, callback)
    end

    it "adds values to the internal roster" do
      roster.add("subscription-1234", user_1, callback)
      expect(roster.internal_roster["node-1"][user_1]).to include "subscription-1234"
    end

    it "adds to redis" do
      # member-added case
      # SADD presence-abcd {user-1}
      #   return value 1 => trigger member_added
      #   return value 0 => no-op
      # SADD slanger-roster-presence-abcd-user-1-node-1 subscription-id
      #presence-channel-user-1 node-1 => [subscription-1, subscription-2]
      expect(Slanger::Redis).to receive(:sadd).
        with("presence-abcd", user_1)

      expect(Slanger::Redis).to receive(:sadd).
        with("slanger-roster-presence-abcd-user-1", "subscription-1234")

      roster.add("subscription-1234", user_1, callback)

      # keys slanger-roster-presence-*-node-*
      # slanger-roster-presence-abcd-user-1-node-1 #contains multiple subscriptions
      #   subscription-1, subscription-2
      # slanger-roster-presence-abcd-user-2-node-1
      #   subscription-4, subscription-3
      # slanger-roster-presence-abcd-user-2-node-2
      # slanger-roster-presence-abcd-user-2-node-3
      #
      # smembers slanger-roster-presence-abcd-user-1-node-1
      #   [subscription-1, subscription-2]
      #slanger-roster-presence-abcd-user-1-node-2 set
      #  [subscription-3, subscription-4]

      # node-1 offline case
      # keys slanger-roster-presence-*-node-1 each do |key|
      #   hdel "slanger-internal-presence-abcd-#{key}", "node-1"
      #

    end
  end

end


