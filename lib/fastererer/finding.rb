# frozen_string_literal: true

module Fastererer
  # Flat, formatter-facing value object for one offense. Carries the raw catalog
  # description verbatim so each format normalizes it its own way.
  Finding = Struct.new(:path, :line, :rule_name, :description, :url, keyword_init: true) do
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
