# frozen_string_literal: true

class Scanner < Enumerator

  def initialize(relation)
    fields = relation.fields
    
    super() do |yielder|
      page_no = 0
      buffer = BufferPool.get_page(relation, 0)
      pos = 0

      loop do
        buffer.pos = pos
        
        # read tuple header
        tuple_header = buffer.read(3)

        
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
        
        pos += 3

        tuple = []
        fields.each do |_, metadata|
          if metadata[:name] == :string
            content_length, _ = buffer.read(2).unpack("S")
            value_length = content_length - 2
            value, _ = buffer.read(value_length).unpack("A#{value_length}")
            pos += content_length
          else
            value, _ = buffer.read(metadata[:size]).unpack(metadata[:template])
            pos += metadata[:size]
          end
          tuple << value
        end

        yielder << tuple
      end
    end
  end
end