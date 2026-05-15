# frozen_string_literal: true

module Fastererer
  class RescueCall
    attr_reader :element, :rescue_classes

    def initialize(node)
      @element = node
      @rescue_classes = []
      set_rescue_classes
    end

    private

    def set_rescue_classes
      @rescue_classes = element.exceptions.filter_map do |exception|
        case exception
        when Prism::ConstantReadNode, Prism::ConstantPathNode
          exception.name
        end
      end
    end
  end
end
