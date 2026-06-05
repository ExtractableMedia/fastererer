# frozen_string_literal: true

require 'prism'

module Fastererer
  class ParseError < StandardError; end

  # Single seam around Prism.parse: returns the AST root or raises ParseError
  class Parser
    def self.parse(ruby_code)
      result = Prism.parse(ruby_code)
      raise ParseError, result.errors.map(&:message).join('; ') if result.failure?

      result.value
    end
  end
end
