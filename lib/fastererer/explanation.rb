# frozen_string_literal: true

require_relative 'rule_catalog'
require_relative 'rule_name'

module Fastererer
  class Explanation
    def self.for(offense_name)
      @instances ||= {}
      @instances[offense_name.to_sym] ||= new(offense_name)
    end

    attr_reader :offense_name

    def initialize(offense_name)
      @offense_name = offense_name.to_sym
      @row = RuleCatalog.fetch(@offense_name)
    end

    def description
      row.fetch('description')
    end

    def url
      row.fetch('url')
    end

    def rule_name
      @rule_name ||= RuleName.from(offense_name)
    end

    # The single source of truth for the rubocop-style line, shared with the text
    # formatter so its output stays byte-for-byte identical to this.
    def self.format_line(rule_name, description, url)
      "#{rule_name}: #{description.delete_suffix('.')}. (#{url})"
    end

    def to_s
      self.class.format_line(rule_name, description, url)
    end

    private

    attr_reader :row
  end
end
