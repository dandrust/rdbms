# frozen_string_literal: true

require_relative "../nested_loop_join.rb"

RSpec.describe NestedLoopJoin do
  let(:inner_relation) { double }
  let(:outer_relation) { double }
  let(:theta)          { ->(_a, _b) { true } }

  let(:instance) { described_class.new(outer_relation, inner_relation, &theta) }

  describe '#initialize' do
    subject(:described_method) { instance }
    it 'sets the outer relation source' do
      expect(described_method.outer_relation).to eq(outer_relation)
    end

    it 'sets the inner relation source' do
      expect(described_method.inner_relation).to eq(inner_relation)
    end

    it 'sets the theta function' do
      expect(described_method.theta).to eq(theta)
    end
  end

  describe '#next' do
    let(:outer_set)   { [[1], [2], [3], [4], :EOF] }
    let(:outer_count) { outer_set.size - 1 }
    let(:inner_set)   { [[:a], [:b], [:c], [:d], [:e], :EOF] }
    let(:inner_count) { inner_set.size - 1 }
    let(:empty_set)   { [:EOF] }

    subject(:described_method) { instance.next }

    let(:result_set) do 
      set = []
      while (tuple = instance.next) != :EOF
        set << tuple
      end
      set
    end

    before do 
      allow(outer_relation).to receive(:next).with(no_args).and_return(*outer_set)
      allow(inner_relation).to receive(:next).with(no_args).and_return(*(inner_set * (outer_count.zero? ? 1 : outer_count)))
      allow(inner_relation).to receive(:rewind).and_return(nil)
    end

    it 'gives the cartesian product' do
      expect(result_set.size).to eq(inner_count * outer_count)
    end

    context "outer relation is emtpy" do
      let(:outer_set) { empty_set }

      it "returns an empty set" do
        expect(result_set).to be_empty
      end
    end

    context "inner relation is empty" do
      let(:inner_set) { empty_set }

      it "returns an empty set" do 
        expect(result_set).to be_empty
      end
    end

    context "with a theta function" do
      let(:outer_set) {  }
      it "doesn't return tuples failing theta"
    end
  end
end