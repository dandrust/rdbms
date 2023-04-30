require_relative '../relation'
require_relative '../scanner'
require 'stringio'

# PASS 0
f = File.open('ratings.db', 'r')
size = f.size
page_size_bytes = 4096
numer_of_pages = size/page_size_bytes
sortable_chunk_size_pages = numer_of_pages/280
sortable_chunk_size_bytes = sortable_chunk_size_pages * page_size_bytes

puts "Reading header"
header_length, _ = *f.pread(4, 0).unpack("L")
header_buffer = f.pread(header_length, 0)
header = Relation::Header.load(header_buffer)

temp_files = 280.map do |n|
  "Iteration #{n}"
  print "\t Reading chunk..."
  offset = sortable_chunk_size_bytes * n
  chunk = f.pread(sortable_chunk_size_bytes, offset)
  puts "done"

  path = "sort_2023_4_29/ratings_sort_#{n}.db"
  temp_file = File.open(path, 'a')
  temp_relation = Relation.new(header.fields, nil, temp_file)

  print "\t Sorting input..."
  sorted = 
    Scanner
    .new(StringIO.new(chunk), header)
    .to_a
    .sort { |a, b| a[3] <=> b[3] }
  print "done"
  
  print "\t Writing sorted results..."
  sorted.each { |t| temp_relation.insert(user_id: t[0], movie_id: t[1], rating: t[2], created_at: t[3]) }
  puts "done"

  temp_file.close
  path
end

f.close


# PASS 1...n

# [[], [], []]
queue = [temp_files]
pass_no = 0
while !queue.empty?
  # Pass definition
  pass_queue = queue.shift

  pass_queue.each_slice(2) do |path_a, path_b, n|
    # TODO: Deal with nil arg - meaning there's an odd number. Simply pass the file through to next pass
    destination_path = "sort_2023_4_29/ratings_sort_pass_#{pass_no}_#{n}.db"
    
    to_be_sorted = DemuxSort.new(iterator_a, iterator_b)

    to_be_sorted.each do |next_tuple|
      destination.insert(user_id: t[0], movie_id: t[1], rating: t[2], created_at: t[3])
    end
  end

  pass_no += 1
end


class DemuxSort < Enumerator
  def initialize(*scanners)
    @scanners = scanners

    @next_values = scanners.map(&:next)

    super() do |y|
      min_value = next_values.min
      min_index = next_values.index_of(min_value)

      begin
        replacement_value = scanners[min_index].next
        next_values[min_index] = replacement_value
      rescue StopIteration
        # remove the iterator and value from the arrays
      end

      y << min_value
    end
  end
end


  

# temp_file.rewind
# sorted_iter = Scanner.new(temp_file, header)

# sorted_iter.each { |r| puts r.to_s }