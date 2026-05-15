# frozen_string_literal: true

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
      traverse_tree(method_definition.body) do |element|
        next unless element.sexp_type == :call

        method_call = MethodCall.new(element)

        if method_call.receiver.is_a?(Fastererer::VariableReference) &&
           method_call.receiver.name == method_definition.block_argument_name &&
           method_call.method_name == :call

          add_offense(:proc_call_vs_yield) && return
        end
      end
    end

    def method_definition
      @method_definition ||= MethodDefinition.new(element)
    end

    def traverse_tree(sexp_tree, &block)
      sexp_tree.each do |element|
        next unless element.is_a?(Array)

        yield element
        traverse_tree(element, &block)
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
      body_first = method_definition.body.first
      expected_ivar = "@#{method_definition.name.to_s.delete_suffix('=')}"

      body_first.sexp_type == :iasgn &&
        body_first[1].to_s == expected_ivar &&
        body_first[2][1] == first_argument.name
    end

    def scan_getter_offense
      return if method_definition.arguments.size.positive?
      return if method_definition.body.size != 1

      add_offense(:getter_vs_attr_reader) if trivial_getter?
    end

    def trivial_getter?
      body_first = method_definition.body.first

      body_first.sexp_type == :ivar &&
        body_first[1].to_s == "@#{method_definition.name}"
    end
  end
end
