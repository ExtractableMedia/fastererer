# frozen_string_literal: true

require_relative 'formatters/text_formatter'
require_relative 'formatters/json_formatter'
require_relative 'formatters/rdjsonl_formatter'

module Fastererer
  class UnknownFormatError < StandardError; end

  # The single source of truth for `--format` values: name -> formatter class.
  module Formatters
    FORMATS = {
      'text' => TextFormatter,
      'json' => JsonFormatter,
      'rdjsonl' => RdjsonlFormatter
    }.freeze

    def self.fetch(name)
      FORMATS.fetch(name) do
        raise UnknownFormatError,
              "Unknown format: #{name.inspect}. Valid formats: #{FORMATS.keys.join(', ')}."
      end
    end
  end
end
