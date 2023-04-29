class CountAggregate
  attr_reader :field, :source, :counter, :field_name, :tuple

  def initialize(field, source)
    @field = field
    @source = source
    @counter = 0
    @field_name = nil
    @tuple = nil
  end

  def next
    if tuple
      reset_counter
    else
      @tuple = source.next
    end

    return tuple if eof?

    set_field_name
    increment_counter

    while can_aggregate?
      @tuple = source.next
      break if eof?
      increment_counter if can_aggregate?
    end

    aggregated_tuple
  end

  def eof?
    tuple == :EOF
  end
  
  def set_field_name
    @field_name = tuple[field]
  end
  
  def increment_counter
    @counter += 1
  end

  def aggregated_tuple
    [field_name, counter]
  end

  def can_aggregate?
    @tuple[self.field] == field_name
  end

  def reset_counter
    @counter = 0
  end
end