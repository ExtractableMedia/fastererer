# frozen_string_literal: true

require_relative 'explanation'

module Fastererer
  class Offense
    attr_reader :offense_name, :line_number

    alias name offense_name
    alias line line_number

    def initialize(offense_name, line_number)
      @offense_name = offense_name
      @line_number  = line_number
      explanation # validate the rule exists eagerly
    end

    def explanation
      @explanation ||= Explanation.new(offense_name)
    end
  end
end
