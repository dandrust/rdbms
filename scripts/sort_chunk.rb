require_relative '../relation'
require_relative '../scanner'
require 'stringio'

f = File.open('ratings.db', 'r')
chunk = f.pread(4096, 4096)

header_length, _ = *f.read(4).unpack("L")
f.rewind

header_buffer = f.read(header_length)

header = Relation::Header.load(header_buffer)

temp_file = File.open('temp.db', 'w+')
temp_relation = Relation.new(header.fields, nil, temp_file)

ordered_set = 
  Scanner
  .new(StringIO.new(chunk), header)
  .to_a
  .sort { |a, b| a[1] <=> b[1] }
  .each { |t| temp_relation.insert(user_id: t[0], movie_id: t[1], rating: t[2], created_at: t[3]) }

temp_file.rewind
sorted_iter = Scanner.new(temp_file, header)

sorted_iter.each { |r| puts r.to_s }