# frozen_string_literal: true

require 'fastererer/rescue_call'
require 'fastererer/offense'
require 'fastererer/scanners/offensive'

module Fastererer
  class RescueCallScanner
    include Fastererer::Offensive

    attr_reader :element

    def initialize(element)
      @element = element
      check_offense
    end

    private

    def check_offense
      return unless rescue_call.rescue_classes.include? :NoMethodError

      add_offense(:rescue_vs_respond_to)
    end

    def rescue_call
      @rescue_call ||= RescueCall.new(element)
    end
  end
end
