# select * from ratings join movies on movies.movieId = ratings.movieId
movies = Relation.from_csv('movies.csv', headers: true)
ratings = Relation.from_csv('ratings_abbreviated.csv', headers: true)

movie_scanner = Scan.new(movies.data)
ratings_scanner = Scan.new(ratings.data)

joiner = Join.new(ratings_scanner, movie_scanner) do |rating, movie|
  rating[:movieId] == movie[:movieId]
end