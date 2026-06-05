def name=(value)
	@name = value
end

class User
	def name=(value)
		@name = value
	end
end

def name=(value)
	@name = [value]
end

def name=(value, &block)
	@name = value
end
