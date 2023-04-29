# frozen_string_literal: true

class Scan
  attr_reader :data, :index

  def initialize(data)
    @data = data
    @index = 0
  end

  def next
    value = 
      if index == data.count
        :EOF 
      else
        data[index]
      end

    @index += 1

    value
  end
end