for number in [*1..100] do
  number
end

for item in [*1..10] do
  item.to_a.shuffle.first
end

# don't catch methods named for
[].for do
end
'ruby'.for('the world')
