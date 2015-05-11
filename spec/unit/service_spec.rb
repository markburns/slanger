require 'spec_helper'

describe Slanger::Service do
  describe "#fetch_node_id!"do
    it do
      expect(Slanger::Redis).to receive(:hincrby).
        with("node", "next_id").
        and_return 1

      Slanger::Service.fetch_node_id!
      expect(Slanger.node_id).to eq 1
    end
  end
end
