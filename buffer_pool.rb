# frozen_string_literal: true

require 'singleton'
require_relative 'buffer'

class BufferPool
  include Singleton
  
  BUFFER_LIMIT = 64

  # TODO: make these private once tested and debugged
  attr_reader :buffers, :content, :files, :references

  def self.method_missing(m, *args, &block)
    instance.send(m, *args, &block)
  end

  private

  def initialize
    @buffers = [nil] * BUFFER_LIMIT
    @content = {}
    @files = {}
    @references = {}
  end

  def get_page(relation, offset = 0)
    path = relation.path

    # Do I have this page in memory?
    buffer_index = if content[path]
      content[path][offset]
    end

    if buffer_index
      @references[@buffers[buffer_index]] ||= { index: buffer_index, refcount: 0 }
      @references[@buffers[buffer_index]][:refcount] += 1
      return buffers[buffer_index] 
    end

    @files[path] ||= File.new(path, 'r+')

    # Is this page index real?
    return if Buffer::SIZE * offset > (@files[path].size - 1)
    
    # Determine which buffer index to use
    # Strategy One: Fill the buffers!
    buffer_index = @buffers.index(&:nil?)

    # Strategy Two: Evict unused buffer
    if buffer_index.nil?
      to_evict, info = @references.find { |_, info| info[:refcount].zero? }
      unless to_evict.nil?
        # Remove from content tracking
        evicted_page_no = @content[path].index(info[:index]) # how do I get the buffer's page number?
        @content[path][evicted_page_no] = nil

        # remove from references
        @references.delete(to_evict)

        buffer_index ||= info[:index] 
      end
    end
    
    # Strategy Three: Fail with OOM exception
    raise "Out of Memory" unless buffer_index

    # Load the page 
    @buffers[buffer_index] = Buffer.new(files[path].pread(Buffer::SIZE, Buffer::SIZE * offset))

    # Track that this page is in the pool
    @content[path] ||= []
    @content[path][offset] = buffer_index

    # Increment refcount
    @references[@buffers[buffer_index]] ||= { index: buffer_index, refcount: 0 }
    @references[@buffers[buffer_index]][:refcount] += 1

    @buffers[buffer_index]
  end

  def return_page(buffer)
    return unless references[buffer]
    @references[buffer][:refcount] -= 1 unless @references[buffer][:refcount].zero?
  end
end

# Ideas!
# def get_page(args, &block)
#   # read the file, do the accounting
#   yield buffer if block_given?
#   # update reference count
# end

# def get_pages(relation)
#   # Return an enumerable that cycles through buffers as you use them up
#   # LazyEnumerator might be helpful here?
#   return BufferIterator.new
# end
