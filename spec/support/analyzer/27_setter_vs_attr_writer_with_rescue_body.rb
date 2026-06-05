def name=(value)
  @name = value
rescue StandardError
  nil
end
