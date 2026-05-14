# frozen_string_literal: true

module Fastererer
  class RescueCall
    attr_reader :element, :rescue_classes

    def initialize(element)
      @element = element
      @rescue_classes = []
      set_rescue_classes
    end

    private

    def set_rescue_classes
      return if element[1].sexp_type != :array

      @rescue_classes = element[1].drop(1).filter_map do |rescue_reference|
        rescue_reference[1] if rescue_reference.sexp_type == :const
      end
    end
  end
end
