require_relative '../relation'

updated_movies = Relation.from_new_db_file('updated_movies.db')

updated_movies.data.each do |tuple|
  puts tuple.last # this should be the movie title
end

puts "EOF"