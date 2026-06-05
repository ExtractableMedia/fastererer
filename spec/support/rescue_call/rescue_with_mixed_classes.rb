begin
  'abakus'.to_a
rescue NoMethodError, ActiveRecord::RecordNotFound
end
