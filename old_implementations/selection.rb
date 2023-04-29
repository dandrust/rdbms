# frozen_string_literal: true

class Selection
  attr_reader :predicate, :source

  def initialize(source, &predicate)
    @predicate = predicate
    @source = source
  end

  def next
    tuple = source.next
    return tuple if eof?(tuple)
  
    while nil_output?(tuple)
      tuple = source.next
      break if eof?(tuple)
    end
        
    tuple
  end

  def nil_output?(tuple)
    tuple.nil? || !predicate.call(tuple)
  end
  
  def eof?(tuple)
    tuple == :EOF
  end
end