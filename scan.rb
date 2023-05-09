# frozen_string_literal: true

class Scan < Enumerator
  def initialize(buffer, schema)

    super() do |yielder|
      pos = 0

      loop do
        buffer.pos = pos
        
        # read tuple header
        tuple_header = buffer.read(Tuple::HEADER_SIZE)

        # Reached end of buffer
        raise StopIteration if tuple_header.nil?

        tuple_present, size = tuple_header.unpack("CS")

        raise StopIteration if tuple_present.zero?
      
        # Go back 3 (tuple header size) so that we can read the ENTIRE tuple at once
        buffer.seek(Tuple::HEADER_SIZE * -1, IO::SEEK_CUR)

        tuple = Tuple.new(buffer.read(size), schema)
        pos += size

        yielder << tuple
      end
    end
  end
end
