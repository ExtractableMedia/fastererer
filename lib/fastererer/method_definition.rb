# frozen_string_literal: true

module Fastererer
  class MethodDefinition
    attr_reader :element, :method_name, :block_argument_name, :body, :arguments

    alias name method_name

    def initialize(node)
      @element = node
      set_method_name
      set_body
      set_arguments
      set_block_argument_name
    end

    def block?
      !!@block_argument_name
    end

    def setter?
      name.to_s.end_with?('=')
    end

    private

    def set_method_name
      @method_name = @element.name
    end

    def set_body
      body_node = @element.body
      @body = if body_node.is_a?(Prism::StatementsNode)
                body_node.body
              else
                []
              end
    end

    def set_arguments
      params = @element.parameters
      return @arguments = [] unless params

      all_params = params.requireds + params.optionals + params.keywords
      @arguments = all_params.map { |p| MethodDefinitionArgument.new(p) }
    end

    def set_block_argument_name
      params = @element.parameters
      return unless params&.block.is_a?(Prism::BlockParameterNode)

      @block_argument_name = params.block.name
    end
  end

  class MethodDefinitionArgument
    attr_reader :element, :name, :type

    def initialize(node)
      @element = node
      set_name
      set_argument_type
    end

    def regular_argument?
      @type == :regular_argument
    end

    def default_argument?
      @type == :default_argument
    end

    def keyword_argument?
      @type == :keyword_argument
    end

    private

    def set_name
      @name = element.name
    end

    def set_argument_type
      @type = case element
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
