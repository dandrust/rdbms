# frozen_string_literal: true

# sorter = Sort.new(movies, :title, :desc)
# sorter = Sort.new(ratings, :created_at)

# Determine how to choose between in-memory vs out-of-core strategies
class Sort < Enumerator

  def initialize(relation, field_label, direction = :asc)

  end
end
