# frozen_string_literal: true

require_relative '../buffer_pool'

RSpec.describe BufferPool do

  it "is initialized with the default buffer limit" do
    expect(described_class.buffer_limit).to eq(described_class::DEFAULT_BUFFER_LIMIT)
  end

  describe ".reset" do
    before { described_class.configure(32) }

    subject(:described_method) { described_class.reset }

    it "sets the buffer limit to the default buffer limit" do
      expect { described_method }.to change { described_class.buffer_limit }.to(described_class::DEFAULT_BUFFER_LIMIT)
    end

    it "clears the buffer pool" do
      expect(described_class).to receive(:clear)
      described_method
    end
  end

  describe ".configure" do
    before { described_class.reset }

    let(:limit) { 16 }
    subject(:described_method) { described_class.configure(limit) }

    it "changes the buffer limit" do
      expect { subject }.to change { described_class.buffer_limit }.to(limit)
    end

    context "values above 64" do
      let(:limit) { 64 }

      it "sets to default buffer limit" do
        expect { subject }.not_to change { described_class.buffer_limit }.from(described_class::DEFAULT_BUFFER_LIMIT)
      end
    end
    
    context "values below 1" do
      [0, -1].each do |val|
        let(:limit) { 0 }

        it "sets the buffer limit to 1" do
          expect { subject }.to change { described_class.buffer_limit }.to(1)
        end
      end
    end

    it "clears the buffer pool" do
      expect(described_class).to receive(:clear)
      described_method
    end
  end

  describe ".clear" do
    subject(:described_method) { described_class.clear }

    it "clears the buffer array" do
      buffer = described_class.get_empty_buffer
      
      expect { described_method }.to change { described_class.buffers.compact.count }.from(1).to(0)
    end

    it "clears the references object" do
      buffer = described_class.get_empty_buffer
      expect { described_method }.to change { described_class.references.keys }.from([buffer]).to([])
    end

    # These have to do with file management. Holding off for now
    it "clears the files object" 
    it "clears the content object"
  end
end