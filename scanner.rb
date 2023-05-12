# frozen_string_literal: true

require_relative 'buffer_pool'
require_relative 'tuple'

class Scanner < Enumerator
  def initialize(relation, schema, header: true)
    super() do |yielder|
      page_no = 0
      buffer = BufferPool.get_page(relation, 0)
      pos = header ? relation.header.length : 0

      loop do
        buffer.pos = pos
        
        # read tuple header
        tuple_header = buffer.read(Tuple::HEADER_SIZE)

        
        # TODO: Not a great design, it would be better if each page
        #       knew how many tuples it contained so we didn't have
        #       to rely on exception handing to detect the end
        # Reached end of buffer
        if tuple_header.nil?
          BufferPool.return_page(buffer)
          page_no += 1
          if buffer = BufferPool.get_page(relation, page_no)
            pos = 0
            next
          else
            raise StopIteration
          end
        end

        tuple_present, size = tuple_header.unpack("CS")

        if tuple_present.zero? # No tuple present
          pos += 1
          next 
        end
      
        # Go back 3 (tuple header size) so that we can read the ENTIRE tuple at once
        buffer.seek(Tuple::HEADER_SIZE * -1, IO::SEEK_CUR)

        tuple = Tuple.new(buffer.read(size), schema)
        pos += size

        yielder << tuple
      end
    end
  end
end