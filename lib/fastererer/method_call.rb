# frozen_string_literal: true

require 'prism'

module Fastererer
  class MethodCall
    attr_reader :element

    def self.build(node)
      node.is_a?(Prism::LambdaNode) ? LambdaCall.new(node) : new(node)
    end

    def initialize(node)
      @element = node
    end

    def receiver
      @receiver ||= ReceiverFactory.build(element.receiver)
    end

    def method_name
      element.name
    end

    def name
      method_name
    end

    def arguments
      @arguments ||= argument_nodes.map { |argument| Argument.new(argument) }
    end

    def block_body
      @block_body ||= block_statements
    end

    def block_argument_names
      @block_argument_names ||= positional_block_parameter_names
    end

    def block?
      !block_node.nil?
    end

    def lambda_literal?
      false
    end

    private

    def block_node
      @block_node ||= element.block
    end

    def argument_nodes
      element.arguments&.arguments || []
    end

    def block_statements
      return unless block_node.is_a?(Prism::BlockNode)

      body = block_node.body
      body.body if body.is_a?(Prism::StatementsNode)
    end

    # Only single positional params convert to &:sym, so a splat or keyword param must not count
    # toward block_argument_names.one?
    def positional_block_parameter_names
      return [] unless block_node.is_a?(Prism::BlockNode)

      params = block_node.parameters
      return [] unless params.is_a?(Prism::BlockParametersNode) && params.parameters

      positional = params.parameters.requireds + params.parameters.optionals
      positional.map { |param| param.is_a?(Prism::MultiTargetNode) ? nil : param.name }
    end
  end

  # A `-> {}` lambda literal. Checks ignore it, so its call attributes are inert
  class LambdaCall < MethodCall
    def receiver = nil
    def method_name = :lambda
    def arguments = []
    def block_body = nil
    def block_argument_names = []
    def block? = true
    def lambda_literal? = true
  end

  module ReceiverFactory
    PRIMITIVE_NODE_TYPES = [Prism::ArrayNode, Prism::RangeNode, Prism::IntegerNode,
                            Prism::FloatNode, Prism::SymbolNode, Prism::StringNode].freeze

    def self.build(node)
      return unless node

      node = unwrap_parentheses(node)
      case node
      # A ConstantPathNode's #name is the unqualified tail only (Foo::Bar => :Bar), which is all
      # the symbol-to-proc check needs; revisit if a check ever needs the fully-qualified path.
      when Prism::LocalVariableReadNode, Prism::ConstantReadNode,
           Prism::ConstantPathNode then VariableReference.new(node)
      when Prism::CallNode then MethodCall.build(node)
      when *PRIMITIVE_NODE_TYPES then Primitive.new(node)
      end
    end

    def self.unwrap_parentheses(node)
      if node.is_a?(Prism::ParenthesesNode) &&
         node.body.is_a?(Prism::StatementsNode) &&
         node.body.body.size == 1
        node.body.body.first
      else
        node
      end
    end
  end

  class VariableReference
    attr_reader :name

    def initialize(node)
      @name = node.name
    end
  end

  class Argument
    attr_reader :element

    def initialize(node)
      @element = node
    end

    TYPE_BY_NODE_CLASS = {
      Prism::KeywordHashNode => :hash,
      Prism::HashNode => :hash,
      Prism::StringNode => :string,
      Prism::IntegerNode => :integer,
      Prism::SymbolNode => :symbol,
      Prism::FloatNode => :float,
      Prism::RegularExpressionNode => :regexp,
      Prism::NilNode => :nil,
      Prism::TrueNode => :boolean,
      Prism::FalseNode => :boolean,
      Prism::LocalVariableReadNode => :variable,
      Prism::CallNode => :method_call
    }.freeze

    def type
      @type ||= TYPE_BY_NODE_CLASS[element.class] || :unknown
    end

    def value
      return @value if defined?(@value)

      @value = case element
               when Prism::StringNode then element.unescaped
               when Prism::IntegerNode, Prism::FloatNode then element.value
               when Prism::SymbolNode then element.unescaped.to_sym
               end
    end
  end

  class Primitive
    attr_reader :element

    def initialize(node)
      @element = node
    end

    def range?
      element.is_a?(Prism::RangeNode)
    end

    def array?
      element.is_a?(Prism::ArrayNode)
    end
  end
end
