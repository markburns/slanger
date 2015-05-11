require 'spec_helper'
require 'lib/slanger/handler.rb'

class ReplacedHandler < Slanger::Handler
  def authenticate
    super
    push_payload nil, 'pusher:info', { message: "Welcome!" }
  end
end

describe 'Replacable handler' do
  it 'says welcome' do
    start_slanger socket_handler: ReplacedHandler

    msgs = em_stream do |websocket, messages|
      if messages.length == 2
        EM.stop
      end
    end

    expect(msgs.last).to eq({ "event" => "pusher:info", "data" =>"{\"message\":\"Welcome!\"}" })
  end
end
