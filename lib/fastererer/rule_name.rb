# frozen_string_literal: true

module Fastererer
  # Derives a rubocop-style "Performance/PascalCase" display name from a snake_case rule key.
  module RuleName
    DEPARTMENT = 'Performance'

    def self.from(offense_name)
      "#{DEPARTMENT}/#{pascal_case(offense_name)}"
    end

    def self.pascal_case(name)
      name.to_s.split('_').filter_map { |part| part.capitalize unless part.empty? }.join
    end
    private_class_method :pascal_case
  end
end
