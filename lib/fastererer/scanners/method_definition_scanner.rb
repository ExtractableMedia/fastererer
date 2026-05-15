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
      block_name = method_definition.block_argument_name
      traverse_tree(method_definition.body) do |node|
        next unless node.is_a?(Prism::CallNode)

        if node.receiver.is_a?(Prism::LocalVariableReadNode) &&
           node.receiver.name == block_name &&
           node.name == :call

          add_offense(:proc_call_vs_yield) && return
        end
      end
    end

    def method_definition
      @method_definition ||= MethodDefinition.new(element)
    end

    def traverse_tree(nodes, &block)
      return unless nodes

      nodes.each do |node|
        next unless node.is_a?(Prism::Node)

        yield node
        child_nodes = node.compact_child_nodes
        traverse_tree(child_nodes, &block)
      end
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
end
