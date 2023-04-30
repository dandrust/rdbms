# frozen_string_literal: true

require_relative 'data_types.rb'

class Relation
  attr_reader :data, :fields, :file

  # 'updated_movies_with_tuple_headers.db'
  def self.from_db_file(path)
    f = File.open(path, 'r+')
    header_length, _ = *f.read(4).unpack("L")
    f.rewind

    header_buffer = f.read(header_length)

    header = Relation::Header.load(header_buffer)

    enumerator = Enumerator.new do |yielder|
      pos = header_length
      loop do
        f.pos = pos
        
        # read tuple header
        begin
          tuple_present, size = f.read(3).unpack("CS")
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
            content_length, _ = f.read(2).unpack("S")
            value_length = content_length - 2
            value, _ = f.read(value_length).unpack("A#{value_length}")
            pos += content_length
          else
            value, _ = f.read(metadata[:size]).unpack(metadata[:template])
            pos += metadata[:size]
          end
          tuple << value
        end
        yielder << tuple
      end
    end

    new(header.fields, enumerator, f)
  end

  def self.from_string(string)
    
  end

  # labels may only be 239 bytes/chars long (255 - 16)
  # { movie_id: DataTypes::INTEGER, created_at: DataTypes::TIMESTAMP }
  # { movie_id: DataTypes::INTEGER, title: DataTypes::STRING }
  # { user_id: DataTypes::INTEGER, movie_id: DataTypes::INTEGER, rating: DataTypes::FLOAT, created_at: DataTypes::TIMESTAMP }
  def self.create(name, field_defs)
    header = Header.new(0, field_defs)
    
    # TODO check that the thing doesn't already exist

    f = File.open("#{name}.db", "a")
    f.write(header.to_s)
    f.close
  end

  def initialize(fields, data, file)
    @fields = fields
    @data = data
    @file = file # should this be here?
  end

  # {movie_id: 1, user_id: 2, rating: 4.5, created_at: 12345}
  # {movie_id: 1, title: "Toy Story (1995)"}
  # TODO: Figure out how to deal with null values
  # for simplicity, I'm assuming that EVERYTHING must be present
  # TODO: Increment the relation's counter when something's inserted
  def insert(tuple)
    # initialize vars
    buffer = []
    template_string = "CS" # first element is a 1 byte header
    tuple_size = 3         # header occupies 1 byte, size occupies 2 bytes

    # pack the buffer with the tuple data
    fields.each do |label, metadata|
      value = tuple[label]

      if metadata[:name] == :string
        template_string += metadata[:template].call(value)
        content_length = metadata[:size].call(value)
        buffer += [content_length, value]
        tuple_size += content_length
      else
        template_string += metadata[:template]
        buffer << value
        tuple_size += metadata[:size]
      end
    end

    # add tuple header
    header = [1, tuple_size]
    buffer.prepend(*header)

    # write to disk
    file.seek(0, :END) # append!

    position = file.pos # EOF
    position_in_current_page = position % 4096
    remaining_in_current_page = 4096 - position_in_current_page

    byte_string = buffer.pack(template_string)

    if byte_string.size > remaining_in_current_page
      # prepend remaining_in_current_page null bytes to the byte_string
      template_string = template_string.prepend("x#{remaining_in_current_page}")
    end

    file.write(buffer.pack(template_string))
  end

  class Header
    HEADER_LENGTH_SIZE_BYTES = 4
    RECORD_COUNT_SIZE_BYTES = 4
    FIELD_COUNT_SIZE_BYTES = 2

    FIELD_DEF_LENGTH_SIZE_BYTES = 1
    FIELD_DEF_DATA_TYPE_SIZE_BYTES = 1
    FIELD_DEF_PREAMPLE_SIZE = FIELD_DEF_LENGTH_SIZE_BYTES + FIELD_DEF_DATA_TYPE_SIZE_BYTES

    FIELD_DEF_START_POS = HEADER_LENGTH_SIZE_BYTES + RECORD_COUNT_SIZE_BYTES + FIELD_COUNT_SIZE_BYTES
    
    attr_reader :record_count, :fields, :length

    def self.load(buffer)
      header_length, record_count, field_count = buffer.unpack("LLS")

      pos = FIELD_DEF_START_POS

      definitions = {}
      field_count.times do
        field_definition_length, field_definition_data_type = buffer[pos..].unpack("CC")
        pos += FIELD_DEF_PREAMPLE_SIZE # each of the values above occupies a single byte
        field_label_length = field_definition_length - FIELD_DEF_PREAMPLE_SIZE
        field_label, _ = buffer[pos..].unpack("A#{field_label_length}")
        pos += field_label_length

        definitions[field_label.to_sym] = DataTypes[field_definition_data_type]
      end

      new(record_count, definitions)
    end

    # { movie_id: DataTypes::INTEGER, created_at: DataTypes::TIMESTAMP, hello_this_is_my_really_long_column_name: DataTypes::TIMESTAMP, oh_hey_heres_another_really_extremely_long_and_descriptive_column_name: DataTypes::TIMESTAMP }
    def initialize(record_count, fields)
      @record_count = record_count
      @fields = fields
    end

    def to_s
      field_count = fields.size
      field_definitions = fields.map do |label, type|
        [FIELD_DEF_LENGTH_SIZE_BYTES + FIELD_DEF_DATA_TYPE_SIZE_BYTES + label.to_s.bytesize, type[:code], label.to_s]
      end

      field_definitions_size_bytes = field_definitions.reduce(0) { |sum, field_def| sum + field_def[0] }

      header_data_size = HEADER_LENGTH_SIZE_BYTES + RECORD_COUNT_SIZE_BYTES + FIELD_COUNT_SIZE_BYTES + field_definitions_size_bytes

      requires_padding = header_data_size % 128 != 0

      header_space_required = 
        if header_data_size <= 128
          128
        else
          # isolate integer part - how many 128s?
          128 * (header_data_size / 128) 
        end
      header_space_required += 128 if requires_padding && header_data_size > 128

      padding_size = header_space_required - header_data_size

      header = [header_space_required, record_count, field_count] + field_definitions.flatten
      (padding_size).times { header << 0 }

      template_string = "LLS#{ field_definitions.map { |field_def| "CCA#{field_def[2].size}" }.join }#{"C#{padding_size}" if requires_padding}"

      header.pack(template_string)
    end
  end
end
