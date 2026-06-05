# frozen_string_literal: true

require 'prism'

module Fastererer
  class RescueCall
    attr_reader :element

    def initialize(node)
      @element = node
    end

    # Only unqualified constants: a namespaced `Foo::NoMethodError` is not the core NoMethodError,
    # so it must not match the rescue_vs_respond_to check.
    def rescue_classes
      @rescue_classes ||= element.exceptions.filter_map do |exception|
        exception.name if exception.is_a?(Prism::ConstantReadNode)
      end
    end
  end
end
