require 'spec_helper'

describe 'Integration:' do

  before(:each) { start_slanger }

  describe 'channel' do
    it "validates the socket id" do
      body = {socket_id: "123"}.to_json
      response = HTTParty.post uri, body: body
      expect(response.code).to eq 400

      body = { socket_id: "123.456", }.to_json
      response = HTTParty.post uri, body: body
      expect(response.code).to eq 401

      socket_id = "POST\n/apps/99759/events\n&dummy="
    end

    def uri
      o = default_slanger_options()
      "http://#{o[:api_host]}:#{o[:api_port]}/apps/#{o[:app_key]}/events"
    end


  end
end

