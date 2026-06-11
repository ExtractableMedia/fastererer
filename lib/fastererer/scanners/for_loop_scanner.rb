# frozen_string_literal: true

require 'fastererer/offense'
require 'fastererer/scanners/offensive'

module Fastererer
  class ForLoopScanner
    include Fastererer::Offensive

    attr_reader :element

    def initialize(element)
      @element = element
      check_offense
    end

    private

    def check_offense
      add_offense(:for_loop_vs_each) # for is always slower than each, so no guard
    end
  end
end
