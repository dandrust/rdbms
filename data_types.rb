# frozen_string_literal: true

module DataTypes
  TYPES = [
    nil, 
    { name: :integer,   code: 0x01, template: "S", size: 2 }, 
    { name: :float,     code: 0x02, template: "F", size: 4 }, 
    { name: :timestamp, code: 0x03, template: "L", size: 4 }, # Until 19 January 2038!
    { name: :string,    code: 0x04, template: ->(content) { "SA#{content.bytesize}" }, size: ->(content) { content.bytesize + 2 } }
  ]

  INTEGER   = TYPES[1]
  FLOAT     = TYPES[2]
  TIMESTAMP = TYPES[3]
  STRING    = TYPES[4]

  module_function
  
  def [](index)
    TYPES[index]
  end
end
