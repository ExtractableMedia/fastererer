h.merge!(item: 1, item2: 3)

h.merge!

h.merge!(item, item: 1)

h.merge(item: 1)

ENUM.each_with_object({}) do |e, h|
  h.merge!(e => e)
end

ENUM.each_with_object({}) do |e, h|
  h[e] = e
end

h.merge!(item: 1)

h.merge!({item: 1})

h.merge!({})

{}.update(item: 1)

Hash.new.update(item: 1)

Hash[a: 1].update(item: 1)

{a: 1}.update(item: 1, item2: 3)

{}.update

h.update(item: 1)

user.update(name: 'x')

Foo::Hash.new.update(item: 1)

Hash.new(0).update(item: 1)

Hash.new { |h, k| h[k] = 0 }.update(item: 1)

Hash[a: 1].update({item: 1})

(Hash.new).update(item: 1)

Hash[a: 1].update({})

update(item: 1)

Foo::Hash[a: 1].update(item: 1)
