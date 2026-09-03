def slow
  ARRAY.select { |x| (x % 10).zero? }.last
end

def fast
  ARRAY.reverse.detect { |x| (x % 10).zero? }
end

ARRAY.select { |x| (x % 10).zero? }.last(5)

[1, 2, 3].last

ARRAY.sort.last
