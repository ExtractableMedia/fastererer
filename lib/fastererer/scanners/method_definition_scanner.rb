# frozen_string_literal: true

require 'prism'
require 'fastererer/method_definition'
require 'fastererer/method_call'
require 'fastererer/offense'
require 'fastererer/scanners/offensive'

module Fastererer
  class MethodDefinitionScanner
    include Fastererer::Offensive

    attr_reader :element

    def initialize(element)
      @element = element
      check_offense
    end

    private

    def check_offense
      if method_definition.block?
        scan_block_call_offense
      else
        scan_getter_and_setter_offense
      end
    end

    def scan_block_call_offense
      visitor = ProcCallVisitor.new(method_definition.block_argument_name)
      method_definition.body.each { |node| node.accept(visitor) }
      add_offense(:proc_call_vs_yield) if visitor.proc_call_found?
    end

    def method_definition
      @method_definition ||= MethodDefinition.new(element)
    end

    def scan_getter_and_setter_offense
      method_definition.setter? ? scan_setter_offense : scan_getter_offense
    end

    def scan_setter_offense
      return if method_definition.arguments.size != 1
      return if method_definition.body.size != 1

      first_argument = method_definition.arguments.first
      return if first_argument.type != :regular_argument

      add_offense(:setter_vs_attr_writer) if trivial_setter?(first_argument)
    end

    def trivial_setter?(first_argument)
      body_node = method_definition.body.first
      return false unless body_node.is_a?(Prism::InstanceVariableWriteNode)
      return false unless body_node.value.is_a?(Prism::LocalVariableReadNode)

      expected_ivar = :"@#{method_definition.name.to_s.delete_suffix('=')}"
      body_node.name == expected_ivar && body_node.value.name == first_argument.name
    end

    def scan_getter_offense
      return if method_definition.arguments.size.positive?
      return if method_definition.body.size != 1

      add_offense(:getter_vs_attr_reader) if trivial_getter?
    end

    def trivial_getter?
      body_node = method_definition.body.first
      expected_ivar = :"@#{method_definition.name}"

      body_node.is_a?(Prism::InstanceVariableReadNode) && body_node.name == expected_ivar
    end
  end

  # Finds `block_name.call` in a method body, without descending into nested def/class/module scopes
  # where the block parameter is no longer in scope
  class ProcCallVisitor < Prism::Visitor
    def initialize(block_name)
      super()
      @block_name = block_name
      @proc_call_found = false
    end

    def proc_call_found?
      @proc_call_found
    end

    def visit_call_node(node)
      @proc_call_found = true if proc_call?(node)
      super
    end

    # No super on purpose: these open a new scope where the block param is unbound, so we stop
    # descending rather than attribute their inner `name.call`s to the enclosing method.
    def visit_def_node(_node)
    end

    def visit_class_node(_node)
    end

    def visit_module_node(_node)
    end

    def visit_singleton_class_node(_node)
    end

    private

    def proc_call?(node)
      return false if @block_name.nil? # an anonymous block param (&) is never invoked by name

      node.receiver.is_a?(Prism::LocalVariableReadNode) &&
        node.receiver.name == @block_name &&
        node.name == :call
    end
  end

  private_constant :ProcCallVisitor
end
