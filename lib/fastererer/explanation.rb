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

    def to_s
      "#{rule_name}: #{description.delete_suffix('.')}. (#{url})"
    end

    private

    attr_reader :row
  end
end
