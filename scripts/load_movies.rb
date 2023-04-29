require_relative '../relation'
require 'csv'

Relation.create('updated_movies_with_tuple_headers', { movie_id: DataTypes::INTEGER, title: DataTypes::STRING })

relation = Relation.from_new_db_file('updated_movies_with_tuple_headers.db')

movies = CSV.open('movies.csv', headers: true)
movies.each do |row|
  tuple = {
    movie_id: row["movieId"].to_i,
    title: row["title"]
  }
  relation.insert(tuple)
end

movies.close
relation.file.close