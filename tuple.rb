# Goal: Work on an in-memory representation of tuples that keeps the serialized bytestring (and it's length!) close by

require 'stringio'

class Tuple
  HEADER_SIZE = 3

  attr_reader :sio, :schema

  def initialize(bytestring, schema)
    @sio = StringIO.new(bytestring)
    @schema = schema
  end

  def bytesize
    sio.size
  end

  def to_s
    sio.rewind
    sio.read
  end

  def values
    @values ||= begin
      tuple = []
      sio.pos = HEADER_SIZE

      schema.map do |_, metadata|
        if metadata[:name] == :string
          content_length, _ = sio.read(2).unpack("S")
          value_length = content_length - 2
          value, _ = sio.read(value_length).unpack("A#{value_length}")
        else
          value, _ = sio.read(metadata[:size]).unpack(metadata[:template])
        end

        value
      end
    end
  end

  def [](index)
    raise IndexError.new("index #{index} outsize of bounds") unless schema.values[index]
    
    values[index]
  end
end

