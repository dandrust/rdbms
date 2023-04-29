# frozen_string_literal: true

class NestedLoopJoin < Enumerator
  DEFAULT = -> (_, _) { true }

  def initialize(outer, inner, &condition)
    condition = DEFAULT unless block_given?

    super() do |yielder|
      outer.each do |o|
        inner.each do |i|
          if condition.call(o, i)
            yielder << [o, i]
            
            # don't finish the inner loop if we've found the match
            break 
          end
        end
      end
    end
  end
end