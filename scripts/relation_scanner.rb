require_relative '../relation'

relation = Relation.from_new_new_db_file('updated_movies_with_tuple_headers.db')

relation.data.each do |tuple|
  puts tuple.last # this should be the movie title
end

puts "EOF"