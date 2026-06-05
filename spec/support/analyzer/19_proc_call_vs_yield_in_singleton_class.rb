def outer(&block)
  obj = Object.new
  class << obj
    block = proc {}
    block.call
  end
end
