# frozen_string_literal: true

module Fastererer
  class MethodCall
    attr_reader :element, :receiver, :method_name, :arguments, :block_body, :block_argument_names

    alias name method_name

    def initialize(node)
      @element = node
      if lambda_literal?
        set_lambda_defaults
      else
        set_receiver
        set_method_name
        set_arguments
        set_block_body
        set_block_argument_names
      end
    end

    def block?
      return true if lambda_literal?

      !element.block.nil?
    end

    def lambda_literal?
      element.is_a?(Prism::LambdaNode)
    end

    private

    def set_lambda_defaults
      @receiver = nil
      @method_name = :lambda
      @arguments = []
      @block_body = nil
      @block_argument_names = []
    end

    def set_receiver
      @receiver = ReceiverFactory.build(element.receiver)
    end

    def set_method_name
      @method_name = element.name
    end

    def set_arguments
      args = element.arguments&.arguments || []
      @arguments = args.map { |arg| ArgumentFactory.build(arg) }
    end

    def set_block_body
      block = element.block
      return unless block.is_a?(Prism::BlockNode)

      body = block.body
      @block_body = body.is_a?(Prism::StatementsNode) ? body.body : nil
    end

    def set_block_argument_names
      block = element.block
      return @block_argument_names = [] unless block.is_a?(Prism::BlockNode)

      params = block.parameters
      unless params.is_a?(Prism::BlockParametersNode) && params.parameters
        return @block_argument_names = []
      end

      @block_argument_names = params.parameters.requireds.map do |param|
        param.is_a?(Prism::RequiredParameterNode) ? param.name : nil
      end
    end
  end

  # Wraps a call's receiver node as a VariableReference, MethodCall, or Primitive.
  module ReceiverFactory
    PRIMITIVE_NODE_TYPES = [Prism::ArrayNode, Prism::RangeNode, Prism::IntegerNode,
                            Prism::FloatNode, Prism::SymbolNode, Prism::StringNode].freeze

    def self.build(node)
      return unless node

      node = unwrap_parentheses(node)
      case node
      when Prism::LocalVariableReadNode,
           Prism::ConstantReadNode, Prism::ConstantPathNode then VariableReference.new(node)
      when Prism::CallNode then MethodCall.new(node)
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

  module ArgumentFactory
    def self.build(node)
      case node
      when Prism::BlockArgumentNode
        BlockArgument.new(node)
      else
        Argument.new(node)
      end
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
      Prism::BlockArgumentNode => :block_pass,
      Prism::StringNode => :string,
      Prism::IntegerNode => :integer,
      Prism::SymbolNode => :symbol,
      Prism::FloatNode => :float,
      Prism::RegularExpressionNode => :regexp
    }.freeze

    def type
      @type ||= TYPE_BY_NODE_CLASS[element.class] || :unknown
    end

    def value
      @value ||= case element
                 when Prism::StringNode then element.unescaped
                 when Prism::IntegerNode, Prism::FloatNode then element.value
                 when Prism::SymbolNode then element.unescaped.to_sym
                 end
    end
  end

  class BlockArgument < Argument
    def type
      :block_pass
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
