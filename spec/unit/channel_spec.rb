require 'spec_helper'
require 'slanger'

def clear_redis_connections
  Slanger::Redis.instance_variables.each do |ivar|
    Slanger::Redis.send :remove_instance_variable, ivar
  end
end

describe 'Slanger::Channel' do
  let(:channel) { Slanger::Channel.new 'test' }

  before(:each) do
    allow(Slanger::Webhook).to receive(:post)
    redis = double('redis', :pubsub => double('redis').as_null_object).as_null_object
    allow(EM::Hiredis).to receive(:connect).and_return redis
    clear_redis_connections
  end

  after(:each) do
    clear_redis_connections
  end

  let(:hincrby) {
    hincrby = double "hincrby"

    hincrby_results.inject([]) do |_, r|
      expect(hincrby).to receive(:callback).and_yield(r)
    end

    hincrby
  }

  before do
    expect(Slanger::Redis).to receive(:hincrby).
      with('channel_subscriber_count', channel.channel_id, subscriber_count_change).
      exactly(hincrby_results.length).times.
      and_return hincrby
  end

  def expect_webhook(type)
    expect(Slanger::Webhook).to receive(:post).
      with(name: type, channel: channel.channel_id).
      once
  end

  describe '#unsubscribe' do
    let(:subscriber_count_change) { -1 }
    let(:hincrby_results) { [2] }
    context 'decrements channel subscribers on Redis' do
      it do
        channel.unsubscribe 1
      end
    end

    context 'activates a webhook when the last subscriber of a channel unsubscribes' do
      before do
        expect_webhook "channel_vacated"
      end

      let(:hincrby_results) { [2,1,0] }

      it do
        3.times { |i| channel.unsubscribe i + 1 }
      end
    end
  end


  describe '#subscribe' do
    let(:subscriber_count_change) { 1 }

    context 'increments channel subscribers on Redis' do
      let(:hincrby_results) { [1] }

      it do
        channel.subscribe { |m| nil }
      end
    end

    context 'activates a webhook when the first subscriber of a channel joins' do
      before do
        expect_webhook 'channel_occupied'
      end

      let(:hincrby_results) { [1, 2, 3] }

      it do
        3.times { channel.subscribe { |m| nil } }
      end
    end
  end
end
