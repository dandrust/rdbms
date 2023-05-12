# frozen_string_literal: true

require_relative '../sort'
require_relative '../data_types'
require_relative '../tuple'

RSpec.describe Sort do
  let(:schema) { {foo: DataTypes::INTEGER } }
  let(:transformer) { ->(x) { x[0] } }
  let(:direction) { :asc }

  subject(:instance) { described_class.new(source.each, schema, direction, &transformer) }

  context "given an empty source" do
    let(:source) { [] }

    it "returns an empty set" do
      expect(subject.to_a).to eq([])
    end
  end

  context "given a source that fits on a single 4kb buffer" do
    let(:sorted_set) { (0..100).to_a }
    let(:source) do
      sorted_set.to_a.shuffle.map { |n| Tuple.new([1, 7, n].pack("CSL"), schema) }
    end

    before do 
      BufferPool.reset
      expect(source.sum(&:bytesize)).to be < 4096
    end

    it "returns a sorted set" do
      expect(subject.to_a.map { |t| t[0] }).to eq(sorted_set)
    end
  end

  context "given a source that fits within the buffer pool's available memory" do
    let(:sorted_set) { (0..600).to_a }
    let(:source) do
      sorted_set.to_a.shuffle.map { |n| Tuple.new([1, 7, n].pack("CSL"), schema) }
    end
    
    before do 
      BufferPool.reset
      BufferPool.configure(2)
      expect(source.sum(&:bytesize)).to be < (2 * 4096)
      expect(source.sum(&:bytesize)).to be > 4096
    end

    it "returns a sorted set" do
      expect(subject.to_a.map { |t| t[0] }).to eq(sorted_set)
    end
  end

  context "given a source that exhausts the buffer pool's available memory" do
    let(:sorted_set) { (0..1500).to_a }
    let(:source) do
      sorted_set.to_a.shuffle.map { |n| Tuple.new([1, 7, n].pack("CSL"), schema) }
    end

    before do 
      BufferPool.reset
      BufferPool.configure(2)
      expect(source.sum(&:bytesize)).to be > (2 * 4096)
    end

    it "returns a sorted set" do
      expect(subject.to_a.map { |t| t[0] }).to eq(sorted_set)
    end
  end

  context "given a source that spills more files to disk than buffers available" do
    let(:sorted_set) { (0..2400).to_a }
    let(:source) do
      sorted_set.to_a.shuffle.map { |n| Tuple.new([1, 7, n].pack("CSL"), schema) }
    end

    before do 
      BufferPool.reset
      BufferPool.configure(2)
      expect(source.sum(&:bytesize)).to be > (2 * 4096) * 2
    end

    it "returns a sorted set" do
      expect(subject.to_a.map { |t| t[0] }).to eq(sorted_set)
    end
  end

  context "extremely large source at full memory capacity" do
    let(:sorted_set) { (0..600_000).to_a }
    let(:source) do
      sorted_set.to_a.shuffle.map { |n| Tuple.new([1, 7, n].pack("CSL"), schema) }
    end

    before do 
      BufferPool.reset
      BufferPool.configure(10)
    end

    it "returns a sorted set" do
      expect(subject.to_a.map { |t| t[0] }).to eq(sorted_set)
    end
  end
end