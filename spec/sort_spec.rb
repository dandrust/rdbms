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

    before { BufferPool.clear }
    before { expect(source.sum(&:bytesize)).to be < 4096 }

    it "returns a sorted set" do
      expect(subject.to_a.map { |t| t[0] }).to eq(sorted_set)
    end
  end

  context "given a source that fits within 64 x 4kb buffers" do
    let(:sorted_set) { (0..1000).to_a }
    let(:source) do
      sorted_set.to_a.shuffle.map { |n| Tuple.new([1, 7, n].pack("CSL"), schema) }
    end
    
    before { BufferPool.clear }
    before { expect(source.sum(&:bytesize)).to be < (64 * 4096) }

    it "returns a sorted set" do
      expect(subject.to_a.map { |t| t[0] }).to eq(sorted_set)
    end
  end

  context "given a source that exhausts 64 x 4kb buffers" do
    let(:sorted_set) { (0..100000).to_a }
    let(:source) do
      sorted_set.to_a.shuffle.map { |n| Tuple.new([1, 7, n].pack("CSL"), schema) }
    end

    before { BufferPool.clear }
    before { expect(source.sum(&:bytesize)).to be > (64 * 4096) }

    it "returns a sorted set" do
      expect(subject.to_a.map { |t| t[0] }).to eq(sorted_set)
    end
  end
end