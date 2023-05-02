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
    .sort { |a, b| a[3] <=> b[3] } # TODO: hard coded to be ascending sort
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
last_pass = false
out = nil

while !queue.empty?
  pass_queue = queue.shift
  puts "starting to process queue with #{queue.length} paths"
  if pass_queue.size <= 50
    puts "queue size is under memory tolerance threshold. Expect return"
    last_pass = true 
  end
  next_queue = []

  pass_queue.each_slice(50).with_index do |paths, n|
    # puts "initializing demux sorter with #{paths.length} scanners (pass #{pass_no}, iteration #{n})"
    scanners = paths.map do |path|
      print "."
      to_read = File.open(path, 'r')
      Scanner.new(to_read, header)
    end
    puts "done"
    
    sorter = DemuxSort.new(*scanners, value_index: 3)

    if last_pass
      "breaking!"
      out = sorter
      break
    end
    
    destination_path = "sort_2023_4_29/ratings_sort_pass_#{pass_no}_#{n}.db"
    puts "creating temp file #{destination_path}"
    destination_file = File.open(destination_path, 'a')
    destination = Relation.new(header.fields, nil, destination_file)

    puts "iterating through sorter, writing to temp file"
    sorter.each do |t|
      # print "."
      destination.insert(user_id: t[0], movie_id: t[1], rating: t[2], created_at: t[3])
    end
    # puts "done"

    puts "closing temp file"
    destination_file.close

    puts "pushing #{destination_path} to next queue"
    next_queue << destination_path
  end

  if next_queue.empty?
    puts "queue is empty, expecting to exit loop"
  else
    puts "pushing next queue to mother queue"
    puts next_queue.to_s
    queue << next_queue  
  end
  
  pass_no += 1
end

# temp_file.rewind
# sorted_iter = Scanner.new(temp_file, header)

# sorted_iter.each { |r| puts r.to_s }