# frozen_string_literal: true

require 'yaml'

module Fastererer
  class UnknownRuleError < StandardError; end

  # Loads, validates, memoizes and looks up the rule catalog from the i18n locale.
  module RuleCatalog
    LOCALE_PATH = File.expand_path('../../config/locales/en.yml', __dir__)

    class << self
      def all
        @all ||= load
      end

      def fetch(offense_name)
        all.fetch(offense_name.to_s) do
          raise UnknownRuleError, "Unknown rule: #{offense_name.inspect}"
        end
      end

      # Guard-only: raises for an unknown rule, returns nil otherwise.
      def validate!(offense_name)
        fetch(offense_name)
        nil
      end

      private

      def load
        rows = read_rows
        rows.each { |key, row| validate_row!(key, row) }
        rows.transform_values { |row| row.transform_values(&:freeze).freeze }.freeze
      end

      def read_rows
        loaded = YAML.safe_load_file(LOCALE_PATH)
        rows = loaded.is_a?(Hash) ? loaded.dig('en', 'fastererer', 'rules') : nil
        return rows if rows.is_a?(Hash)

        raise "Fastererer locale at #{LOCALE_PATH} is missing the 'en.fastererer.rules' section"
      rescue Errno::ENOENT
        raise "Fastererer locale file not found at #{LOCALE_PATH}"
      rescue Psych::SyntaxError => e
        raise "Fastererer locale at #{LOCALE_PATH} is not valid YAML: #{e.message}"
      end

      def validate_row!(key, row)
        raise "Fastererer rule #{key} is malformed: #{row.inspect}" unless row.is_a?(Hash)

        validate_url!(key, row['url'])
        validate_description!(key, row['description'])
      end

      def validate_url!(key, url)
        unless url.is_a?(String) && url.start_with?('https://')
          raise "Fastererer rule #{key} has a non-https url: #{url.inspect}"
        end

        return if url.match?(/\A[[:print:]]+\z/)

        raise "Fastererer rule #{key} has a non-printable url: #{url.inspect}"
      end

      def validate_description!(key, text)
        return if text.is_a?(String) && text.match?(/\A[[:print:][:space:]]+\z/)

        raise "Fastererer rule #{key} has a non-printable description: #{text.inspect}"
      end

      # Test-only hook: clears the memoized catalog so the YAML can be re-read.
      def reset!
        @all = nil
      end
    end
  end
end
