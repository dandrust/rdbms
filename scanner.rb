# frozen_string_literal: true

class Scanner < Enumerator

  def initialize(io, header)
    super() do |yielder|
      pos = 0
      loop do
        io.pos = pos
        
        # read tuple header
        begin
          tuple_present, size = io.read(3).unpack("CS")
        rescue
          raise StopIteration
        end
        if tuple_present.zero?
          pos += 1
          next 
        end
        
        pos += 3

        tuple = []
        header.fields.each do |_, metadata|
          if metadata[:name] == :string
            content_length, _ = io.read(2).unpack("S")
            value_length = content_length - 2
            value, _ = io.read(value_length).unpack("A#{value_length}")
            pos += content_length
          else
            value, _ = io.read(metadata[:size]).unpack(metadata[:template])
            pos += metadata[:size]
          end
          tuple << value
        end
        yielder << tuple
      end
    end
  end
end