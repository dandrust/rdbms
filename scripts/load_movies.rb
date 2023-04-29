require_relative '../relation'
require 'csv'

Relation.create('updated_movies', { movie_id: DataTypes::INTEGER, title: DataTypes::STRING })

updated_movies_relation = Relation.from_new_db_file('updated_movies.db')

movies = CSV.open('movies.csv', headers: true)
movies.each do |row|
  tuple = {
    movie_id: row["movieId"].to_i,
    title: row["title"]
  }
  updated_movies_relation.insert(tuple)
end

movies.close
updated_movies_relation.file.close