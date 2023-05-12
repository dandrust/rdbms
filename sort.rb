# frozen_string_literal: true

require_relative 'buffer_pool'
require_relative 'scan'
require_relative 'scanner'
require 'securerandom'

class Sort < Enumerator

  def initialize(source, schema, direction, &transform)
    @source = source
    @sorted_buffers = []
    @sorted_files = []
    @transform = transform
    @schema = schema

    @sorter = if direction == :asc
      ->(a, b) { a <=> b } 
    else
      ->(a, b) { b <=> a }
    end

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
        commit_to_file if spilled_to_disk?
        break
      end 
    end
    
    while @sorted_files.count > BufferPool.buffer_limit
      files_to_merge = @sorted_files.shift(BufferPool.buffer_limit) # get the number of files that we can stream through available memory
      
      new_file = write_temporary_file(
        files_to_merge.map { |f| Scanner.new(f, schema, header: false) }
      )

      @sorted_files << new_file
      files_to_merge.each { |f| f.close; File.delete(f.path) }
    end

    @final_sources = 
      if spilled_to_disk?
        @sorted_files.map { |f| Scanner.new(f, schema, header: false) }
      else
        @sorted_buffers.map { |buf| Scan.new(buf, schema) }
      end
    
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
          if spilled_to_disk?
            file_to_delete = @sorted_files[next_tuple_index]
            
            file_to_delete.close
            File.delete(file_to_delete.path)
            @sorted_files.delete_at(next_tuple_index)
          end

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
    sort_and_flush
  
    # reset state
    begin
      @buffer = BufferPool.get_empty_buffer
    rescue BufferPool::OutOfMemory
      file_handle = write_temporary_file(@sorted_buffers.map { |buf| Scan.new(buf, @schema) })
      @sorted_files << file_handle
      
      # @buffer still holds a buffer -- the call to replace it failed and landed us here
      # We'll return all of our @sorted_buffers to the pool except @buffer
      # Then we'll reset it's state by clearing it
      
      @sorted_buffers.each { |b| BufferPool.return_page(b) unless b == @buffer }
      @sorted_buffers.clear

      @buffer.clear
    end
  
    @byte_count = 0
    @to_sort = []
  end

  def write_temporary_file(sources)
    path = File.join("tmp", "#{SecureRandom.uuid}.tmp.db")
    file = File.open(path, 'a')

    bytes_written = 0

    next_candidate_tuples = sources.map(&:next)

    while !next_candidate_tuples.empty?
      next_tuple = next_candidate_tuples.min do |a, b|
        @sorter.call(@transform.call(a), @transform.call(b))
      end

      next_tuple_index = next_candidate_tuples.index(next_tuple)
      
      begin
        replacement_tuple = sources[next_tuple_index].next
        next_candidate_tuples[next_tuple_index] = replacement_tuple
      rescue StopIteration
        sources.delete_at(next_tuple_index)
        next_candidate_tuples.delete_at(next_tuple_index)
      end

      position_in_current_page = bytes_written % 4096
      remaining_in_current_page = 4096 - position_in_current_page

      if remaining_in_current_page < next_tuple.bytesize
        padding = [].pack("x#{remaining_in_current_page}")
        file.write(padding)

        bytes_written += remaining_in_current_page
      end
      
      file.write(next_tuple.to_s)

      bytes_written += next_tuple.bytesize
    end
    file.close
    file
  end

  def spilled_to_disk?
    @sorted_files.any?
  end

  def commit_to_file # called at the end of the divide phase
    file_handle = write_temporary_file(@sorted_buffers.map { |buf| Scan.new(buf, @schema) })
    @sorted_files << file_handle

    # Clean up state, return memory
    @buffer = nil
    @sorted_buffers.each { |b| BufferPool.return_page(b) }
    @byte_count = 0
    @to_sort = []
  end
end
