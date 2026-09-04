# frozen_string_literal: true

module Fastererer
  # Carries the raw catalog description so each format can normalize it its own way
  Finding = Data.define(:path, :line, :rule_name, :description, :url) do
    def self.from(offense, path)
      explanation = offense.explanation

      new(
        path: path.to_s,
        line: offense.line_number,
        rule_name: explanation.rule_name,
        description: explanation.description,
        url: explanation.url
      )
    end
  end
end
