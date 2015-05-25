require 'spec_helper'

describe 'Integration:' do
  before(:each) { start_slanger log_file: STDOUT, log_level: ::Logger::DEBUG, debug: true}

  describe 'channel' do
    it "validates the socket id" do
      body = {socket_id: "123"}.to_json
      puts default_slanger_options

      response = HTTParty.post uri, body: body, timeout: 6000
      expect(response.code).to eq 400

      body = { socket_id: "123.456", }.to_json
      response = HTTParty.post uri, body: body
      expect(response.code).to eq 401

    end

    def uri
      o = default_slanger_options()
      "http://127.0.0.1:4567/apps/#{o[:app_key]}/events"
    end
  end
end

