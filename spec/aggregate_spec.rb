# frozen_string_literal: true

require 'rspec'
require_relative '../aggregate'

RSpec.describe Aggregate do
  let(:transform) { described_class::IDENTITY }
  subject { described_class.new(source, &transform).to_a }

  context "a single value" do
    let(:source) { [100].to_enum }
    it { is_expected.to eq([[100, 1]]) }
  end

  context "a single value repeated" do
    let(:source) { [100, 100].to_enum }
    it { is_expected.to eq([[100, 2]]) }
  end

  context "empty source" do
    let(:source) { [].to_enum }
    it { is_expected.to eq([]) }
  end

  context "multiple values" do
    let(:source) { [:a, :a, :a, :b, :b, :c, :d, :d, :d, :d, :d].to_enum }
    it { is_expected.to eq([[:a, 3], [:b, 2], [:c, 1], [:d, 5]]) }
  end

  describe "tranformation" do
    let(:source) do 
      [
        ["hi", "hello"],
        ["hi", "bye"],
        ["hola", "bye"],
        ["hi", "farewell"],
        ["bonjour", "farewell"],
      ].to_enum
    end

    let(:transform) { ->(tuple) { tuple[1] }  }

    it do 
      is_expected.to eq(
        [
          ["hello", 1],
          ["bye", 2],
          ["farewell", 2]
        ]
      )
    end
  end
end
