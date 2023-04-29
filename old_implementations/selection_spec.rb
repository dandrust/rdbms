# frozen_string_literal: true

require_relative '../selection.rb'

RSpec.describe Selection do
  let(:in_memory_source) { double }
  let(:predicate)        { ->(tuple) { nil } }

  let(:instance) { described_class.new(in_memory_source, &predicate) }

  describe '#initialize' do
    it 'sets the source' do
      expect(instance.predicate).to eq(predicate)
    end

    it 'sets the predicate block' do
      expect(instance.source).to eq(in_memory_source)
    end
  end

  describe '#next' do
    let(:value)     { 1 }
    let(:tuple_set) { [value] }

    subject(:described_method) { instance.next }

    before do
      allow(in_memory_source).to receive(:next).and_return(*tuple_set)
    end

    context 'when the predicate is true' do
      let(:predicate) { ->(tuple) { true } }

      it 'returns the next tuple' do
        expect(described_method).to eq(value)
      end
    end

    context 'when a nil tuple is present' do
      let(:tuple_set) { [nil, nil, value] }
      let(:predicate) { ->(tuple) { true } }
      
      it 'returns the following tuple' do
        expect(described_method).to eq(value)
      end
    end

    context 'when the predicate is false' do
      let(:tuple_set) { [false, value] }
      let(:predicate) { ->(tuple) { tuple } }
      
      it 'returns the following tuple' do
        expect(described_method).to eq(value)
      end
    end
  end
end