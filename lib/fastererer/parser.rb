# frozen_string_literal: true

require 'ruby_parser'

module Fastererer
  class Parser
    PARSER_CLASS = RubyParser

    def self.parse(ruby_code)
      PARSER_CLASS.for_current_ruby.parse(ruby_code)
    end
  end
end
