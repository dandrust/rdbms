# frozen_string_literal: true

require_relative 'buffer_pool'
require_relative 'scan'

class Sort < Enumerator

  def initialize(source, schema, direction, &transform)
    @source = source
    @sorted_buffers = []
    @sorted_files = []
    @transform = transform

    @sorter = if direction == :asc
      ->(a, b) { a <=> b } 
    else
      ->(a, b) { b <=> a }
    end

    @file_no = 0

    
    @byte_count = 0
    @to_sort = []

    begin
      tuple = source.next
    rescue
      return super() {}
    end

    @buffer = BufferPool.get_empty_buffer

    while tuple
      add_to_buffer(tuple)
      begin
        tuple = source.next
      rescue StopIteration
        # Clean up wherever we are in the process
        sort_and_flush if @to_sort.any?
        break
      end 
    end
    
    
    # Then we'll have to figure out
    # what we have (buffers, files, etc) 
    # and how much memory is available.
    # From there, we'll choose a strategy 
    # until we have a source count <= buffer
    # count. Then we can start yielding tuples

    @final_sources = @sorted_buffers.map { |buf| Scan.new(buf, schema) }
    next_candidate_tuples = @final_sources.map(&:next)

    super() do |yielder|
      loop do
        raise StopIteration if next_candidate_tuples.empty?
        
        next_tuple = next_candidate_tuples.min do |a, b|
          @sorter.call(@transform.call(a), @transform.call(b))
        end

        next_tuple_index = next_candidate_tuples.index(next_tuple)
        
        begin
          replacement_tuple = @final_sources[next_tuple_index].next
          next_candidate_tuples[next_tuple_index] = replacement_tuple
        rescue StopIteration
          @final_sources.delete_at(next_tuple_index)
          next_candidate_tuples.delete_at(next_tuple_index)

        end
        yielder << next_tuple
      end
    end
  end

  def add_to_buffer(tuple)
    switch_out_buffer if Buffer::SIZE - @byte_count < tuple.bytesize

    @to_sort << tuple
    @byte_count += tuple.bytesize
  end

  def sort_and_flush
    # sort the tuples and write to current buffer
    @to_sort
      .sort { |a, b| @sorter.call(@transform.call(a), @transform.call(b)) }
      .each { |t| @buffer.write(t.to_s) }
  
    # Keep a reference to the sorted buffer for later
    @sorted_buffers << @buffer
  end
  
  def switch_out_buffer
    # puts "byte_count is #{@byte_count}"
    sort_and_flush
  
    # reset state
    begin
      @buffer = BufferPool.get_empty_buffer
    rescue BufferPool::OutOfMemory
      file_handle = write_temporary_file
      @sorted_files << file_handle
      
      # keep the buffer you have and clear it, it's contents are safe on disk
      @sorted_buffers.except(@buffer).each { |b| BufferPool.return_page(@buffer) }
    end
  
    @byte_count = 0
    @to_sort = []
  end
end







# class Relation
#   @tuple_klass

#   def initialize
#     @tuple_klass = Struct.new(*fields) do
#       # Can structs have instance vars that aren't memebers?

#       attr_reader :serialized_bytestring

#       def serialize
#         @serialized_bytestring ||= begin
#           # serialize the thing
#         end
#       end
#       def deserialize; end
#     end
#   end
# end

# module Serialization
#   module_function

#   def serialize_tuple(tuple, schema)
#     buffer = []
#     template_string = "CS" # first element is a 1 byte header
#     tuple_size = 3         # header occupies 1 byte, size occupies 2 bytes

#     # pack the buffer with the tuple data
#     # TODO: Make schema an array of field objects
#     schema.each do |label, metadata|
#       value = tuple[label]

#       if metadata[:name] == :string
#         template_string += metadata[:template].call(value)
#         content_length = metadata[:size].call(value)
#         buffer += [content_length, value]
#         tuple_size += content_length
#       else
#         template_string += metadata[:template]
#         buffer << value
#         tuple_size += metadata[:size]
#       end
#     end

#     # add tuple header
#     header = [1, tuple_size]
#     buffer.prepend(*header)

#     buffer.pack(template_string)
#   end
# end


#THIS WORKS!  From #initialize
# loop do
#   begin
#     # Get as many tuples as fit 4kb
#     while Buffer::SIZE - byte_count > tuple.bytesize
#       to_sort << tuple
#       byte_count += tuple.bytesize
#       begin
#         tuple = source.next
#       rescue
#         raise "no more tuples in source!"
#       end
#     end

#     # sort the tuples and write to a buffer
#     to_sort
#       .sort(&sorter)
#       .each { |t| buffer.write(t.to_s) }
    
#     # Keep a reference to the sorted buffer for later
#     @sorted_buffers << buffer

#     # reset state
#     buffer = BufferPool.get_empty_buffer
#     byte_count = 0
#     to_sort = []
#   rescue BufferPool::OutOfMemory
#     file = File.new("sort_#{file_no}.tmp.db", a)
#     # Demux sort, stream to file
#     # Return pages to buffer pool
#     # start the loop again
#   end
# end