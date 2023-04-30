class OldRelationMethods
  def self.from_csv(*args)
    csv = CSV.open(*args)
    enumerator = csv.each.map(&:to_h).map(&:values).to_enum

    new(csv.headers, enumerator)
  end

  # 'ratings.db'
  def self.from_db_file(fields, path, record_length, binary_template_string)
    f = File.open(path, 'r')
    enumerator = Enumerator.new do |yielder|
      loop do 
        data = f.read(record_length)
        if data
          yielder << data.unpack(binary_template_string)
        else
          raise StopIteration
        end
      end
    end
  
    new(fields, enumerator)
  end

  # 'movies.db'
  def self.from_new_db_file(path)
    f = File.open(path, 'r+')
    header_length, _ = *f.read(4).unpack("L")
    f.rewind

    header_buffer = f.read(header_length)

    header = Relation::Header.load(header_buffer)

    enumerator = Enumerator.new do |yielder|
      pos = header_length
      loop do
        f.pos = pos
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
end
