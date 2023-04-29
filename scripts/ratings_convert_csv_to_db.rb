# Convert CSV representation of the data to a binary encoded file format
# Represent primary keys as 16 bit ints - S
# Represent rating values as single-precision floats - F
# Represent unix timestamps as 32 bit ints - L
# Add 32 bit padding at end of record

# Record size = 128 bits/16 bytes (4096/16 = 256 records per 4kb page)

source = File.new('ratings.csv', 'r')
dest = File.new('ratings.db', 'a', binmode: true)

source.gets("\r\n") # ignore headers

while input = source.gets("\r\n")&.chomp
  user_id, movie_id, rating, timestamp = *input.split(',')
  
  dest.write([user_id.to_i, movie_id.to_i, rating.to_f, timestamp.to_i, 0].pack("SSFLL"))
end

source.close
dest.close