# frozen_string_literal: true

module ParserHelpers
  def parse_first_statement(code)
    Fastererer::Parser.parse(code).statements.body.first
  end
end
