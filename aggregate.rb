# frozen_string_literal: true

class Aggregate < Enumerator
  IDENTITY = ->(x) { x }
  
  def initialize(source, &transform)
    @source = source
    @count = 1
    @transformer = transform || IDENTITY

    begin
      @current_value = consume!
    rescue StopIteration
      return super() {}
    end
      
    super() do |yielder|
      @out = yielder

      loop do
        @count += 1 while same_as_current_value?(value = consume)
        emit_value

        @current_value = value
        @count = 1
      end
    end
  end

  private

  def consume!
    value = @source.next
    @transformer.call(value)
  end

  def consume
    consume!
  rescue StopIteration
    terminate!
  end

  def terminate!
    emit_value
    raise StopIteration
  end

  def emit_value
    @out << [@current_value, @count]
  end

  def same_as_current_value?(value)
    value == @current_value
  end
end

# class Aggregate < Enumerator
#   def initialize(source)
#     begin
#       value = source.next

#       next_value = nil
#       count = 1
      
#       super() do |yielder|
#         loop do
          
#           begin
#             # If it's the same value as last time
#             while (next_value = source.next) == value
#               # increment the counter
#               count += 1
#               next
#             end
#           rescue StopIteration
#             # Be sure to flush the last value and count
#             # when we hit the end of the source
#             yielder << [value, count]
#             raise StopIteration
#           end

#           # Value has changed!
#           yielder << [value, count]
          
#           value = next_value
#           count = 1
#         end
#       end
#     rescue StopIteration
#       # Source is empty, so return an empty enumerator
#       super([])
#     end
#   end
# end

