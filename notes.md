# 4/15/2023
## Enumerate all the things
Revisited this project. Noticed that scan, selection, and nested loop joins (the iterator/executor nodes) had the same interface as ruby enumerators. Read about enumerators and converted each into classes that inherit from enumerator. From there, I was able to implement a very simple query:

```ruby
# select * from ratings join movies on movies.movieId = ratings.movieId
movies = Relation.from_csv('movies.csv', headers: true)
ratings = Relation.from_csv('ratings_abbreviated.csv', headers: true)

movie_scanner = Scan.new(movies.data)
ratings_scanner = Scan.new(ratings.data)

joiner = Join.new(ratings_scanner, movie_scanner) do |rating, movie|
  rating[:movieId] == movie[:movieId]
end
```

## Sorting
Looking at the Bradfield DB syllabus, it recommends out-of-core sorting and hashing. The first half of this [Berkely lecture](https://archive.org/details/ucberkeley_webcast_FGvKL2cmZEo) covers sorting. I wanted to try implementing the naive sorting algorithm which would sort a large file a block at a time, committing the sorted results to disk. Then incrementally zip sorted files together until arriving at one single sorted file on disk.  

Exactly how this fits into implementing `order by` I'm not quite sure yet. But I figured getting my hands dirty might bring up some interesting questions and ideas.  I'm focusing my attention on the `ratings.csv` file because it's gigantic and neither my editor nor ruby wants to load it into memory, understandably.

### Binary encoded file format
Reading the CSV in predictable size chunks was difficult because of varying-length strings, even without string data types. So I spent my effort implementing a binary encoded file rather than fiddling with how to stictch 4k chunks of CSV strings together. See `ratings_convert_csv_to_db.rb`. Pack/unpack was easy - this being my third rodeo.

### Sorting runs an optimal file size
It's 2:30am. I tried the naive implementation and ended up nearly bricking the computer because I wasn writing thousands of 4096 byte files. The better implementation where you use more RAM and build fewer, bigger files was way more practical. Finally, I have ~280 files on disk at around 1MB that are sorted!

### Merging, and using the Relation abstraction
I chose to merge 20 of the "pass 0" artifacts to test the implementation. I write an implementation for the `Relation` class to read a `.db` file. That let me focus on just streaming the data I need at hand vs thinking about page sizes and pulling in pages at a time and draining/replacing those behind an `iterator.next` interface.

I'm not sure that I want to follow this further without perhaps writing some test cases to show that things are being ordered correctly. A quick spot check of the first 100 records of the sorted output looked good! Though, the process ended with a `StopIteration` exception having been raised, so it'd also be nice to fix up the `Relation` classes to handle that a bit more gracefully.

* Improve `Relation`/iterator EOF handling
* Add headers to the file format (data types too?)
* Write tests around sorting
* Ability to express field name (or field position?) to be sorted by
* Improve the merge algorithm to maybe keep the relations/values sorted, and then do an ordered insert when a new value is pulled

## Relations
At this point, I'm not playing with sorting anymore. I'd like to, but I want to strengthen the relation model so that it's an abstraction I can reach for when doing it.  Go slow to go fast, I hope.

### Revamping the file format
I've added a header so that the caller doesn't need to know any information about schema. Additionally, I've made the record layout much more condensed and variable length, so callers won't be about to read, eg. 16 bytes at a time all the time

### Inserts
I've added a first implementation of inserting records and I've looped over the movies csv to populate `movies.db`

### Left to do
Lots!
* Increment record size in header
* Figure out how to represent null values in the record
* Organize records within a file so that the file can be broken into 4k pages
- Update my enumerator implementations so that they can read the variable-length record layout (done!)

From there, especially after I have the 4k page business worked out, I'd like to get back to sorting. The idea is that I'll be able to easily fetch page after page and sort it. Sorting the movies table -- or rather, something I can comfortably fit into memory -- will make generalizing the algorithm a bit simplier.

I may also try to port this to Rust or something so that I can work with memory more directly. Some of the page size stuff may be more relevant (or even easier to reason about) if I'm not fighting the VM's interface.

## Something to try next?
After talking with ChatGPT about how to capture null fields - implement a null bitmap

Try not to design the perfect thing. Let the implementation evolve as you implement new features!

Problem at hand: representing nil values
Intuition:
* Need some tuple/row level metadata where I can store a null bitmap
* Null byte array needs to only apply to fields that are nullable
  * If a table doesn't' contain any nullable fields, perhaps it's tuples don't need a null bitmap

Approach:
* Just add this to your existing implementation
* Existing implementation reserves space for a data types because nulls aren't present. Change this so that no memory is wasted by null values
* Eliminating reserved space for null values will mean that records will be variable length even if it doesn't contain a string.  It might be convenient to encode the length of the tuple in the header
  * On the other hand, tuples can be arbitrarily large. Is it fair for a table scan to simply have to read each value?
  * Instead of length, perhaps offset of next tuple would work better?
* In the spirit of the first line of this doc, perhaps don't change anything unless you NEED to. Your current implementation reads through each field to arrive at the next tuple -- just keep it that way! You can read the null bit array first to know if you need to read to get a value, or if you should just return the null value.

Ideas:
* Try writing the tuple to disk in rust. Given an array/collection of key/value structs (some of them null!), encode and write the result to a file
  * Get a feel for what this would be like in Rust. Easier? Harder? Rust stands out because I can play with memory management AND I can have conveniences like iterator interfaces, etc.

## A way forward in Ruby?
* Pull off in-core sorting with large out-of-core data
* Goal: Still use Ruby, and interrogate it's implementation along the way
  * https://stackoverflow.com/questions/6701103/understanding-ruby-and-os-i-o-buffering
* The whole reason I went on the path of binary encoding is that I wanted to be able to easily grab data to sort without having to worry about that data spilling over a boundary (ie, 4096 bytes)

## April 28, 2023
I've come back to this after a week or so away. I'd gotten a little bogged down with wanting to know everything before doing anything.  After taking stock, I'd really like to use the Berkely lectures as a guide so I'll stick to that content.  I went on the side quest with making a binary-encoded format so that I could reliably grab a chunk of data without worrying that I'd grab half a record at the end of the chunk. In doing that, I realized that fixed-size records worked great when there were integers, floats, and timestamps involved. But strings were a bit trickier!  So I expanded my file format but in doing so I wasn't careful about boundaries, so I was back at square one where if I grab a predetermined chunk of data I might have a tuple that spans the boudnary.

So today I revisited the way that I'm inserting tuples so that I don't write a record across a 4096 byte boundary (0x1000). However, that breaks code that reads back the records! 

For next time: How will I have the code reading a file know that it's reached the last tuple on a 4kb block? As long as the first long it reads is zero, will that be enough to signal that it's time to grab a new block?

# April 29 2023:
*Goal*: Modify relation scan iterator code to deal with data gaps at page boundaries

*Solution*: Add a tuple header that includes a non-null byte to indicate that a tuple is present

A bit of a winding road this morning.  Initially I thought that putting a 2 byte integer representing tuple size would work nicely. If we read a zero size, then the reader can just keep reading until it reads on non-zero size.

The issue with that approach was that the padding at the end of a 4kb page could be and odd number of bytes - which meant that reading a 16 bit int would pick up "junk" data past the 4kb page boundary.

My simple solution was to include a tuple header whose first by is non-zero, and then read only a single byte to determine presence.  If a null byte is read, it's essentially a "null tuple" header.

This means that records no longer span the 4kb boundary! Next time, I can look into reading a 4kb page at a time. That gets me back on track to work on the out-of-core merge sort algorithm -- being able to read some fixed number of pages at a time, sort those, and write the sorted set back to disk.


# Questions from IO class
* What is fcntl? (syscall)
* What is ioctl? (syscall)
* What is fsync? (syscall)
* pread is atomic....huh?
* read takes an output buffer - could that be a good way to read a page?
  * then, would I have a StringIO instance?  Is that a thing?
* IO#sync -> skips ruby bufferring, but doesn't guarantee that OS isn't buffering data

# Sorting
* Load the data into memory by scanning the table and populating an array
* Sort the array according to a predicate
* Write the data to a file

# April 29, 2023 Pt 2
I re-built the ratings database file to use the updated format that I worked out this morning.  From there, I played around with `IO.pread` (*positional* read) to grab a 4kb chunk at a 4096 byte offset. Worked like a charm!

From there, I started extracting the table-scanning iterator into it's own executor class.  Since you can wrap a string with the `StringIO` class, the `Scanner` class can take a `File` or a `StringIO`.

Finally, `sort_chunk.rb` is a proof-of-concept for reading a chunk of a database file, sorting it in-memory, and then writing the result back to disk.

Next up is to write an out-of-core sorting algorithm to sort the entire ratings database file!

# April 30, 2023
**Goal**: Sort the ratings.db file by creation timestamp without reading the entire file into memory.

Sorting algo
x   x    x    x    x    x   - read a set into memory
  x        x         x      - stream the tuples
      x              x      - stream the tuples
             x - sorted file


**Goal**: Finish implementing a DemuxSort class, see it working

Completing the implementation of `DemuxSort` took longer than anticipated because I forgot to put a looping construct in the enumerator and spun my wheels debugging.  In any case, it's done!

For a manual test I initialized three scanners and passed them to the sorting class, ordering by timestamp.  It worked!  However, I was puzzled when I tried sorting by a different column and direction.  The results were chaotic.  BUT! That's because the scanner sources need to be ordered in the same way that the demux sorter is ordering.  Otherwise the algorithm doesn't make sense.  You can't divide and conquer if your strategy changes between the diving and the conquering!  My puzzled looks near the end of the video can be resolved.

My puzzlement led me to want to put `DemuxSort` under test next time, but I don't think I will. It would be nice to have things under test, but I think that might deflate my motivation. Instead, I'd like to get back to implementing the pass 1..n code.

Of note, the divide and conquer strategy seems useful for a general case -- even if the dataset to be sorted isn't so large to require out-of-core sorting.  That is, it may be useful to still operate on chunks of data (eg, 4kb) and sort those, then put the sorted pages behind a demux sort interface.  In that case, I'd think that the `DemuxSort` implementation I have is nice because it takes a scanner instance and the scanner can worry about the details of what and how it's scanning.  Though, I should be sure that scanners reading from disk are reading 4kb at a time so that we get enough data for each IO.

Next time, finish up pass 1..n loop!

**Goal:** Implement pass 1..n, see it working

I may go on a side quest to write a buffer management layer so that I can have some constraints to work with (eg, only allow 64 4kb buffers at a time). That would also allow me to think more in buffers and pages and to design iterators around those abstractions (whereas now, I'm just using Ruby's buffering and, as far as my Ruby code is concerned, constantly doing small reads from the underlying file). As a bonus, I could incorporate some multithreading where I have a "warm" buffer that's being filled as a main buffer is being drained.


**Goal:** Sketch out a buffer pool concept, thinking about file management

File -> entire db file
Page -> 4kb chunk of a file (tuples across bounadry)
Buffer -> 4kb StringIO object in Ruby, representing a page in a file

Relation might hold a reference to it's file's path
The actual file IO happens in the buffer pool
  - responsible for opening and closing and reading and writing to persistent storage
  - Responsibilities
    - Managing a limited set of in-memory objects
    - Managing file IO

```ruby
class ByteArray
  def initialize(size)
    [].pack(template)
  end

  def [](idx)
  end

  def template
    # depending on size, choose a suitable type
  end
end
```

```ruby
BufferPool.load_page(file_path, page_no)

# Asks the buffer pool to fetch the first page of the underlying file
# In order to get field information
Relation.new(path)


# DML

# Asks the buffer pool to fetch the last page of the underlying file
# writes a tuple to the buffer
# write the buffer back to the file
relation.insert(tuple)

# Updates and deletes follow a similar pattern as insert:
#  - Read a page from persistent storage
#  - modify the page in memory
#  - write the entire page back to persistent storage

# Querying

# Relation holds the PATH
# Scan requests the first page
# Scan iterates through the first page's tuples
# Scan requests the second page
# ...
# Scan raises StopIteration
Scan.new(relation)

relation.size times do |n|
  b = BufferPool.get_page(relation, n)
  while ...
    y << tuple
  end
end

i = relation[1]
...iterate
i = relation[2]
...iterate
i = relation[3]


# Relation holds the PATH
# Sort requests X buffers
# Sort sorts each of the buffers in memory 
#  - be careful to indicate that these aren't modifications to the relation)
# Sort demultiplexes the sorted buffers to iterate
Sort.new(relation, column, direction)

# Example use case: GROUP BY
# Relation holds the PATH
# Hash would request X buffers (empty)
# Hash would write tuples to buffers
# ...
HashThing.new(relation)

# No buffers required?
# It's just a stitcher with two iterators upstream
NestedLoopJoin.new(a, b, conditions)
```

Next time, implement a scan node iterator that's buffer-aware. Have the scan node indicate when it's done with a buffer