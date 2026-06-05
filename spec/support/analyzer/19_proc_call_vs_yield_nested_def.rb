def outer(&block)
  def inner(&block)
    block.call
  end
end
