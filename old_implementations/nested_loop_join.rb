# frozen_string_literal: true

class NestedLoopJoin
  DEFAULT_THETA = ->(_, _) { true }

  attr_reader :outer_relation, :inner_relation, :theta, :outer
  
  def initialize(outer_relation, inner_relation, &theta)
    @outer_relation = outer_relation
    @inner_relation = inner_relation
    @theta = block_given? ? theta : DEFAULT_THETA
    @fetch_next_outer = true
  end

  def next
    # Deal with the outer, if needed
    @outer = fetch_next_outer! if fetch_next_outer?

    # If the outer reaches EOF, we're done-done
    return :EOF if eof?(outer)

    # Get the next inner
    inner = inner_relation.next

    # Use a while loop here instead of just an if
    # so that if the inner relation is empty we exhaust
    # the outer relation and get to and EOF state
    while eof?(inner)
      @outer = fetch_next_outer!
      return :EOF if eof?(outer)
      rewind_inner!
      inner = inner_relation.next
    end

    [outer, inner]
  end

  def fetch_next_outer?
    @fetch_next_outer
  end

  def rewind_inner!
    inner_relation.rewind
  end

  def eof?(tuple)
    tuple == :EOF
  end

  def fetch_next_outer!
    # Indicate that we don't need to fetch an outer tuple on the next `next`
    @fetch_next_outer = false
    outer_relation.next
  end
end