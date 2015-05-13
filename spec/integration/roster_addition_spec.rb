require 'spec_helper'
require 'slanger'

describe Slanger::Presence::RosterAddition do
  let(:roster) { Slanger::Presence::Roster.new channel_id }
  let(:channel_id) { "presence-abcd" }

  before do
    allow(Slanger).to receive(:node_id).and_return "N1"

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
    { "N1" => ["S1"],
      "N2" => ["S2"] }
  end

  let(:subscriptions_2) do
    { "N3" => ["S3", "S4"],
      "N2" => ["S5"] }
  end

  {{"user_id"=>"1", "user_info"=>{}}=>{
    "N1"=>["S1"],
    "N2"=>["S2"]},

  {"user_id"=>"2", "user_info"=>{"something"=>"here"}}=>{
    "N3"=>["S3", "S4"],
    "N2"=>["S5"]}}

  describe "#add" do
    before do
    end

    let(:callback) { double "callback", call: nil }

    it "calls the callback" do
      expect(callback).to receive :call
      roster.add("N1", "S1234", user_1, callback)
    end

    it "adds values to the internal roster" do
      roster.add("N1", "S1234", user_1, callback)
      expect(roster.internal_roster[user_1]["N1"]).to include "S1234"
    end

    it "adds to redis" do
      # member-added case
      # SADD presence-abcd {user-1}
      #   return value 1 => trigger member_added
      #   return value 0 => no-op
      # SADD slanger-roster-presence-abcd-user-1-N1 Sid
      #presence-channel-user-1 N1 => [S1, S2]
      expect(Slanger::Redis).to receive(:sadd).
        with("presence-abcd", user_1)

      expect(Slanger::Redis).to receive(:sadd).
        with("slanger-roster-presence-abcd-user-1", "S1234")

      roster.add("N1", "S1234", user_1, callback)

    end
  end

end


