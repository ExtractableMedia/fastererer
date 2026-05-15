# frozen_string_literal: true

require 'yaml'

module Fastererer
  class Explanation
    DEPARTMENT = 'Performance'
    LOCALE_PATH = File.expand_path('../../config/locales/en.yml', __dir__)

    class UnknownRuleError < StandardError; end

    def self.rules
      @rules ||= load_rules
    end

    def self.validate!(offense_name)
      rules.fetch(offense_name.to_s) do
        raise UnknownRuleError, "Unknown rule: #{offense_name.inspect}"
      end
    end

    def self.load_rules
      data = YAML.safe_load_file(LOCALE_PATH).dig('en', 'fastererer', 'rules')
      unless data.is_a?(Hash)
        raise "Fastererer locale at #{LOCALE_PATH} is missing the 'en.fastererer.rules' section"
      end

      data.transform_values { |row| row.transform_values(&:freeze).freeze }.freeze
    rescue Errno::ENOENT
      raise "Fastererer locale file not found at #{LOCALE_PATH}"
    end
    private_class_method :load_rules

    attr_reader :offense_name

    def initialize(offense_name)
      @offense_name = offense_name
      @data = self.class.validate!(offense_name)
    end

    def description
      @data.fetch('description')
    end

    def url
      @data.fetch('url')
    end

    def rule_name
      @rule_name ||= "#{DEPARTMENT}/#{pascal_case(offense_name)}"
    end

    def to_s
      "#{rule_name}: #{description}. (#{url})"
    end

    private

    def pascal_case(name)
      name.to_s.split('_').map(&:capitalize).join
    end
  end
end
