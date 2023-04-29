source = File.open('ratings.db', 'r')

# Sort chunks
i = 0
block_size = 4096
allowed_blocks = 280
capacity_limit = block_size * allowed_blocks # mimic sized buffers
current_capacity = 0
buffer = []

while record = source.read(16) # read 16 bytes/128 bits
  buffer << record.unpack("SSFLL")
  current_capacity += 16

  if current_capacity == capacity_limit
    puts "writing to file #{i}"
    f = File.new("ratings_sort_#{i}.tmp.db", "a")

    # sort the buffer in-memory
    buffer
      .sort { |a, b| a[3] <=> b[3] }
      .each do |r| 
        f.write(r.pack("SSFLL"))
      end
    f.close

    # accounting vars
    i += 1
    current_capacity = 0
    buffer.clear
  end
end

source.close

# Read N files with sorted records and write a single file that has all records from N, sorted

# merge chunks
available_buffers = 20

# Open an output file
output = File.open('ratings_sort_pass1_0.tmp.db', 'a')

# Get a reference to enumerators over the db files
buffers = available_buffers.times.map do |i|
  Relation.from_db_file([:user_id, :movie_id, :rating, :timestamp], "ratings_sort_#{i}.tmp.db", 16, "SSFLL")
end

# Get the initial set of values from the buffers
values = buffers.map { |r| r.data.next }

while !buffers.empty?
  # Potential optimization: if only one buffer remains, write what's
  # left of it to the output file
  if buffers.size == 1
    # ...
  end

  # Find the lowest value and where it came from
  lowest = values.min_by { |r| r[3] }
  buffer_index_of_lowest = values.index(lowest)

  # write the lowest record to the output file
  puts "writing data from relation at index #{buffer_index_of_lowest}"
  output.write(lowest.pack("SSFLL"))

  # Gather any consecutive records from the buffer with the same value
  while buffers[buffer_index_of_lowest].data.peek[3] == lowest[3]
    puts "writing consecutive lowest value data from relation at index #{buffer_index_of_lowest}"
    output.write(buffers[buffer_index_of_lowest].data.next.pack("SSFLL"))
  end

  # replace the lowest (already outputted) record with the next one from it's 
  # source buffer or, if we've reach EOF, remove the buffer
  if !buffers[buffer_index_of_lowest].data.peek # no more data
    puts "buffer #{buffer_index_of_lowest} has no more data!"
    # TODO: You should be closing the file
    buffers.delete_at(buffer_index_of_lowest)
    values.delete_at(buffer_index_of_lowest)
  else
    puts "pulling next record from relation #{buffer_index_of_lowest}"
    values[buffer_index_of_lowest] = buffers[buffer_index_of_lowest].data.next
  end
    
end