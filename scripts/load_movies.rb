require_relative '../relation'
require 'csv'

Relation.create('updated_ratings_with_tuple_headers', { user_id: DataTypes::INTEGER, movie_id: DataTypes::INTEGER, rating: DataTypes::FLOAT, created_at: DataTypes::TIMESTAMP })

relation = Relation.from_new_db_file('updated_ratings_with_tuple_headers.db')

movies = CSV.open('ratings.csv', headers: true)
movies.each do |row|
  tuple = {
    user_id: row["userId"].to_i,
    movie_id: row["movieId"].to_i,
    rating: row["rating"].to_f,
    created_at: row["timestamp"].to_i
  }
  relation.insert(tuple)
end

movies.close
relation.file.close