# frozen_string_literal: true

require_relative 'formatters/text_formatter'
require_relative 'formatters/json_formatter'
require_relative 'formatters/rdjsonl_formatter'
require_relative 'formatters/github_formatter'

module Fastererer
  class UnknownFormatError < StandardError; end

  module Formatters
    FORMATS = {
      'text' => TextFormatter,
      'json' => JsonFormatter,
      'rdjsonl' => RdjsonlFormatter,
      'github' => GithubFormatter
    }.freeze

    def self.fetch(name)
      FORMATS.fetch(name) do
        raise UnknownFormatError,
              "Unknown format: #{name.inspect}. Valid formats: #{FORMATS.keys.join(', ')}."
      end
    end
  end
end
