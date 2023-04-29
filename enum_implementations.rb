
a = [[1, "foo"], [2, "bar"], [3, "baz"], [4, "buz"], [5, "ping"]] 

b = [[1, "a", 1], [2, "b", 4], [3, "c", 2], [4, "d", 5], [5, "e", 5], [6, "f", 1], [7, "g", 3]] 
b = [[1, "a", 1], [2, "b", 1], [3, "c", 1], [4, "d", 1], [5, "e", 1], [6, "f", 1], [7, "g", 1]] 

condition = ->(x, y) { x[0] == y[2] }

out = []

b.each do |b_tuple|
  a.each do |a_tuple|
    out << [b_tuple, a_tuple] if condition.call(a_tuple, b_tuple)
  end
end

Enumerator.new do |y|
  b.each do |b_tuple|
    a.each do |a_tuple|
      y << [b_tuple, a_tuple] if condition.call(a_tuple, b_tuple)
    end
  end
end

class Relation
  attr_reader :data, :fields

  def self.from_csv(*args)
    csv = CSV.open(*args)
    enumerator = csv.each.map(&:to_h).map(&:values).to_enum

    new(csv.headers, enumerator)
  end

  def self.from_db_file(fields, path, record_length, binary_template_string)
    f = File.open(path, 'r')
    enumerator = Enumerator.new do |yielder|
      loop do 
        data = f.read(record_length)
        if data
          yielder << data.unpack(binary_template_string)
        else
          raise StopIteration
        end
      end
    end
  
    new(fields, enumerator)
  end

  def initialize(fields, data)
    @fields = fields
    @data = data
  end
end

class Scan < Enumerator; end

class NestedLoopJoin < Enumerator
  DEFAULT = -> (_, _) { true }

  def initialize(outer, inner, &condition)
    condition = DEFAULT unless block_given?

    super() do |yielder|
      outer.each do |o|
        inner.each do |i|
          if condition.call(o, i)
            yielder << [o, i] 
            
            # don't finish the inner loop if we've found the match
            break 
          end
        end
      end
    end
  end
end

# select * from ratings join movies on movies.movieId = ratings.movieId
movies = Relation.from_csv('movies.csv', headers: true)
ratings = Relation.from_csv('ratings_abbreviated.csv', headers: true)

movie_scanner = Scan.new(movies.data)
ratings_scanner = Scan.new(ratings.data)

joiner = Join.new(ratings_scanner, movie_scanner) do |rating, movie|
  rating[:movieId] == movie[:movieId]
end
