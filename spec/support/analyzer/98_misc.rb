name = 'damir'
name.gsub('a', 'o')

class Greeter
  def initialize(language)
    @language = language.gsub(' ', '_')
  end

  def greet(target)
    "Hello, #{target.gsub('!', '.')}"
  end
end

'a b c'.gsub(' ', '-')
