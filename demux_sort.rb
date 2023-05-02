# frozen_string_literal: true

class DemuxSort < Enumerator
  def initialize(*scanners, value_index:, direction: :asc)
    super() do |yielder|
      next_tuples = scanners.map(&:next)

      loop do
        next_tuple = if direction == :desc
            next_tuples.max { |a, b| a[value_index] <=> b[value_index] }
          else
            next_tuples.min { |a, b| a[value_index] <=> b[value_index] }
          end
        next_tuple_index = next_tuples.index(next_tuple)

        begin
          replacement_tuple = scanners[next_tuple_index].next
          next_tuples[next_tuple_index] = replacement_tuple
        rescue StopIteration
          scanners.delete_at(next_tuple_index)
          next_tuples.delete_at(next_tuple_index)
        end

        raise StopIteration if next_tuples.empty?

        yielder << next_tuple
      end
    end
  end
end