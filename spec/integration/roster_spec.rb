#encoding: utf-8

require 'spec_helper'

describe "PresenceChannel Roster" do

  context "with multiple instances of channel connections to the same PresenceChannel (i.e. multiple nodes)" do
    #the slanger node memoizes channels in a class instance variable
    #this sidesteps that memoization so mimicking multiple nodes
    let(:presence_1) { Slanger::PresenceChannel.new :channel_id => "presence-channel" }
    let(:presence_2) { Slanger::PresenceChannel.new :channel_id => "presence-channel" }

    before do
      start_slanger

      Slanger::Connection::RandomSocketId.
        expects(:next).
        times(4).
        returns( "random-socket-id-1", "random-socket-id-2", "random-socket-id-3", "random-socket-id-4")

      em_stream do
        Slanger::PresenceChannel.
          expects(:create).
          times(2).
          returns(presence_1, presence_2)
        presence_1.expects(:next_random).returns "random-subscription-id-1"
        presence_2.expects(:next_random).returns "random-subscription-id-2"


        EM.stop
      end

      Slanger.expects(:node_id).times(2).returns(1, 2)
    end

    it do
      messages = em_stream do |ws_1, messages|
        case messages.length
        when 1

          sleep 0.1
          send_subscribe(user: ws_1,
                         user_id: '0f177369a3b71275d25ab1b44db9f95f',
                         name: 'MB',
                         message: messages[0])
        when 2
          ws_2 = new_websocket
          Slanger.error "sleep 1"
          sleep 1
          send_subscribe(user: ws_2,
                         user_id: '1234',
                         name: 'LG',
                         message: messages[1])
          Slanger.error "sleep 0.1"
          sleep 0.5

        when 3
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
