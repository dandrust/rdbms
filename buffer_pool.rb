# frozen_string_literal: true

require 'singleton'
require_relative 'buffer'

class BufferPool
  include Singleton
  
  BUFFER_LIMIT = 64

  # TODO: make these private once tested and debugged
  attr_reader :buffers, :content, :files

  def self.method_missing(m, *args, &block)
    instance.send(m, *args, &block)
  end

  private
  
  def initialize
    @buffers = [nil] * BUFFER_LIMIT
    @content = {}
    @files = {}
  end

  def get_page(relation, offset = 0)
    path = relation.path

    # Do I have this page in memory?
    buffer_index = if content[path]
      content[path][offset]
    end

    return buffers[buffer_index] if buffer_index

    @files[path] ||= File.new(path, 'r+')
    
    # TODO: Work out eviction so that we don't proactively
    # clear buffers, meaning we keep the cache warm
    buffer_index = @buffers.index(&:nil?)

    raise "Out of Memory" unless buffer_index

    @content[path] ||= []
    @content[path][offset] = buffer_index
    @buffers[buffer_index] = Buffer.new(files[path].pread(Buffer::SIZE, Buffer::SIZE * offset))
  end
end

