# frozen_string_literal: true

require 'singleton'
require_relative 'buffer'

class BufferPool
  include Singleton

  class OutOfMemory < RuntimeError; end
  
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

  def clear
    @buffers.clear
    @buffers = [nil] * BUFFER_LIMIT
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
    
    buffer_index = next_available_buffer_index!

    # Load the page 
    @buffers[buffer_index] = Buffer.new(files[path].pread(Buffer::SIZE, Buffer::SIZE * offset))

    # Track that this page is in the pool
    @content[path] ||= []
    @content[path][offset] = buffer_index

    # Increment refcount
    @references[@buffers[buffer_index]] ||= { index: buffer_index, refcount: 0, path: nil }
    @references[@buffers[buffer_index]][:path] = path
    @references[@buffers[buffer_index]][:refcount] += 1

    @buffers[buffer_index]
  end

  def return_page(buffer)
    buffer.clear
    return unless references[buffer]
    @references[buffer][:refcount] -= 1 unless @references[buffer][:refcount].zero?
  end
  alias return_buffer return_page

  def get_empty_buffer
    buffer_index = next_available_buffer_index!

    # Create the buffer
    @buffers[buffer_index] = Buffer.new

    # Increment refcount
    @references[@buffers[buffer_index]] ||= { index: buffer_index, refcount: 0 }
    @references[@buffers[buffer_index]][:refcount] += 1

    @buffers[buffer_index]
  end

  def next_available_buffer_index!
    # Strategy One: Fill the buffers!
    buffer_index = @buffers.index(&:nil?)

    return buffer_index unless buffer_index.nil?

    # Strategy Two: Evict unused buffer
    buffer_to_evict, info = @references.find { |_, info| info[:refcount].zero? }
    buffer_index = evict_buffer(buffer_to_evict, info) unless buffer_to_evict.nil?

    return buffer_index unless buffer_index.nil?
    
    raise OutOfMemory
  end

  def evict_buffer(buffer, reference_info)
    # remove from content tracking
    if path = reference_info[:path]
      page_no = @content[path].index(reference_info[:index])
      @content[path][page_no] = nil
    end

    # remove from references
    @references.delete(buffer)

    reference_info[:index]
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
