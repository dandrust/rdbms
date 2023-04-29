# frozen_string_literal: true

require_relative '../count_aggregate.rb'

RSpec.describe CountAggregate do
  let(:field)  { 0 }
  let(:source) { double }

  let(:instance) { described_class.new(field, source) }
  
  describe "#initialize" do
    subject(:described_method) { instance }

    it 'sets the field to aggregate' do
      expect(described_method.field).to eq(field)
    end

    it 'set the stream source' do
      expect(described_method.source).to eq(source)
    end

    it 'initializes the counter to zero' do
      expect(described_method.counter).to be_zero
    end
  end

  describe "#next" do
    subject(:described_method) { instance.next }
    let(:foo_set)   { [[:foo], [:foo], [:foo], [:foo]] }
    let(:foo_count) { foo_set.size }
    let(:data_set)  { [*foo_set, :EOF] }

    before do
      allow(source).to receive(:next).with(no_args).and_return(*data_set)
    end

    it 'counts occurences of identical elements' do
      expect(described_method).to eq([:foo, foo_count])
    end

    context "empty set" do
      let(:data_set) { [:EOF] }

      it "returns EOF" do
        expect(described_method).to eq(:EOF)
      end
    end

    context "when only one element present" do
      let(:data_set) { [[:foo], :EOF] }
      it "returns a count of one" do
        expect(described_method).to eq([:foo, 1])
      end
    end

    context "when multiple elements are present" do
      let(:foo_set)   { [[:foo], [:foo], [:foo]] }
      let(:foo_count) { foo_set.size }
      let(:bar_set)   { [[:bar], [:bar]] }
      let(:bar_count) { bar_set.size }
      let(:baz_set)   { [[:baz], [:baz], [:baz], [:baz], [:baz], [:baz]] }
      let(:baz_count) { baz_set.size }
      let(:data_set)  { [*foo_set, *bar_set, *baz_set, :EOF] }
      let(:result_set) { [] }

      before do
        while count_tuple = instance.next
          break if count_tuple == :EOF
          result_set << count_tuple
        end
      end

      it "returns counts for each unique element" do
        expect(result_set).to contain_exactly(
          [:foo, foo_count],
          [:bar, bar_count],
          [:baz, baz_count],
        )
      end
      context "when elements are unsorted/ungrouped" do
        let(:other_foo_set)   { [[:foo], [:foo]] }
        let(:other_foo_count) { other_foo_set.size }
        let(:data_set)  { [*foo_set, *bar_set, *other_foo_set, *baz_set, :EOF] }
        it "returns counts of contingous unique elements" do
          expect(result_set).to contain_exactly(
            [:foo, foo_count],
            [:foo, other_foo_count],
            [:bar, bar_count],
            [:baz, baz_count],
          )
        end
      end
    end

    

  end
end