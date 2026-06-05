# A rescue/ensure body is a BeginNode; its block call must still be detected.
def call_me(number, zumba, &block)
  block.call
rescue StandardError
  nil
end
