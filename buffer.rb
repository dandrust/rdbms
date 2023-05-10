# frozen_string_literal: true
require 'stringio'

class Buffer < StringIO
  SIZE = 4096

  def clear
    truncate(0)
    rewind
  end
end
