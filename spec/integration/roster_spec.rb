#encoding: utf-8

require 'spec_helper'

describe "PresenceChannel Roster" do
  before { start_slanger }

  context "with multiple instances of channel connections to the same PresenceChannel (i.e. multiple nodes)" do
    #the slanger node memoizes channels in a class instance variable 
    #this sidesteps that memoization so mimicking multiple nodes
    let(:presence_1) { Slanger::PresenceChannel.new :channel_id => "presence-channel" }
    let(:presence_2) { Slanger::PresenceChannel.new :channel_id => "presence-channel" }

    it do
     messages = em_stream do |websocket, messages|
        case messages.length
        when 1
          Slanger::PresenceChannel.
            expects(:find_or_create_by_channel_id).
            times(2).
            returns(presence_1, presence_2)

          presence_1.expects(:next_random).returns "random-subscription-id-1"
          presence_2.expects(:next_random).returns "random-subscription-id-2"

          Slanger.expects(:node_id).times(2).returns(1, 2)

          send_subscribe( user: new_websocket,
                         user_id: '0f177369a3b71275d25ab1b44db9f95f',
                         name: 'MB',
                         message: messages.first)
        when 2
          Slanger.error "sleep 1"
          sleep 0.1
          #give enough time for redis to be updated
          send_subscribe( user: new_websocket,
                         user_id: '0f177369a3b71275d25ab1b44db9f95f',
                         name: 'MB',
                         message: messages.first)
        when 3
          Slanger.error "sleep 0.1"
          sleep 0.1
          EM.stop
        end
     end

     user_1 = {"user_id" => "0f177369a3b71275d25ab1b44db9f95f", "user_info" => {}}

     roster = {
       user_1 => {
         "node:1" => ["subscription:random-subscription-id-1"],
         "node:2" => ["subscription:random-subscription-id-2"]
       }
     }

     presence_1.roster.should == roster

     presence_1.subscribers.length.should == 2
     presence_2.subscribers.length.should == 2




    end
  end
end
