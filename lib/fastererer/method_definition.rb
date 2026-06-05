# frozen_string_literal: true

require 'prism'

module Fastererer
  class MethodDefinition
    PARAMETER_CATEGORIES = %i[requireds optionals rest posts keywords keyword_rest block].freeze
    private_constant :PARAMETER_CATEGORIES

    attr_reader :element

    def initialize(node)
      @element = node
    end

    def method_name
      element.name
    end
    alias name method_name

    def body
      @body ||= statement_body
    end

    def arguments
      @arguments ||= parameter_nodes.map { |node| MethodDefinitionArgument.new(node) }
    end

    def block_argument_name
      block_parameter&.name
    end

    def block?
      !block_parameter.nil?
    end

    def setter?
      name.to_s.end_with?('=')
    end

    private

    def statement_body
      body_node = element.body
      # A rescue/ensure body is a BeginNode wrapping the statements; #statements may be nil
      body_node = body_node.statements if body_node.is_a?(Prism::BeginNode)
      body_node.is_a?(Prism::StatementsNode) ? body_node.body : []
    end

    def parameter_nodes
      params = element.parameters
      return [] unless params

      PARAMETER_CATEGORIES.flat_map { |category| Array(params.public_send(category)) }
    end

    def block_parameter
      params = element.parameters
      return unless params&.block.is_a?(Prism::BlockParameterNode)

      params.block
    end
  end

  class MethodDefinitionArgument
    attr_reader :element

    def initialize(node)
      @element = node
    end

    # Prism param nodes expose #name (nil when anonymous); MultiTargetNode has none
    def name
      element.respond_to?(:name) ? element.name : nil
    end

    def type
      @type ||= argument_type
    end

    def regular_argument?
      type == :regular_argument
    end

    def default_argument?
      type == :default_argument
    end

    def keyword_argument?
      type == :keyword_argument
    end

    private

    def argument_type
      case element
      when Prism::RequiredParameterNode
        :regular_argument
      when Prism::OptionalParameterNode
        :default_argument
      when Prism::RequiredKeywordParameterNode,
           Prism::OptionalKeywordParameterNode
        :keyword_argument
      end
    end
  end
end
