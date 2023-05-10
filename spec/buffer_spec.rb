# frozen_string_literal: true

require_relative '../buffer'

RSpec.describe Buffer do
  describe "#clear" do
    let(:content) { "This is my test string "}
    let(:instance) { described_class.new(content) }

    subject(:described_method) { instance.clear }
    
    # TODO: I have no idea why initializing a Buffer in the spec
    # opens it a non-writable. Is there interference with another
    # buffer class?
    xit "clears the underlying string object" do
      expect { described_method }.to change { instance.string }.from("This is my test string").to("")
    end
  end
end