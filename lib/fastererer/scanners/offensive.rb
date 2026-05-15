# frozen_string_literal: true

require 'fastererer/offense'

module Fastererer
  module Offensive
    attr_accessor :offense

    def offensive?
      !!offense
    end

    alias offense_detected? offensive?

    private

    def add_offense(offense_name)
      self.offense = Fastererer::Offense.new(offense_name, element.location.start_line)
    end

    def check_offense
      raise NotImplementedError
    end
  end
end
