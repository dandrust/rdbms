# frozen_string_literal: true

require_relative '../scan.rb'

RSpec.describe Scan do
  let(:data) do
    [
      [1, :foo],
      [2, :bar],
      [3, :baz],
      [4, :buzz]
    ]
  end

  let(:instance) { described_class.new(data) }

  describe '#initialize' do
    subject(:described_method) { instance }

    it 'loads the data' do
      expect(described_method.data).to eq(data)
    end

    it 'sets the index to 0' do
      expect(described_method.index).to be_zero
    end
  end

  describe '#next' do
    let(:tuple) { ["I'm", 'a', 'little', 'tuple'] }
    let(:data)  { [tuple] }

    subject(:described_method) { instance.next }

    it 'increments the index' do
      expect { described_method }.to change { instance.index }.by(1)
    end

    context 'when no tuples remain' do
      let(:data) { [] }

      it 'returns EOF when no data remains' do
        expect(described_method).to eq(:EOF)
      end  
    end

    it 'returns the next tuple' do
      expect(described_method).to eq(tuple)
    end
  end
end