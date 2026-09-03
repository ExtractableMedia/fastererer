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

def []=(key, value)
	@data[key] = value
end

def name=(value)
	@name = value
	@dirty = true
end

def name=(*values)
	@name = values
end

def name=(value)
	puts value
end
