# frozen_string_literal: true

require 'prism'
require 'fastererer/method_call'

module Fastererer
  # Includer must respond to #method_call (returning a MethodCall) and #add_offense(symbol)
  # (the latter via the Offensive mixin).
  module SymbolToProcCheck
    private

    def check_symbol_to_proc
      return unless symbol_to_proc_candidate?

      body_call = MethodCall.build(method_call.block_body.first)
      return unless symbol_to_proc_body?(body_call)

      add_offense(:block_vs_symbol_to_proc)
    end

    def symbol_to_proc_candidate?
      method_call.block_argument_names.one? &&
        single_call_body? &&
        method_call.arguments.none? &&
        !method_call.lambda_literal?
    end

    # A safe-nav body (foo&.bar) is excluded: arr.map(&:bar) raises on a nil element, so the rewrite
    # would not preserve behavior
    def single_call_body?
      body = method_call.block_body
      body&.size == 1 && body.first.is_a?(Prism::CallNode) && !body.first.safe_navigation?
    end

    def symbol_to_proc_body?(body_call)
      body_call.arguments.none? &&
        !body_call.block? &&
        !body_call.receiver.nil? &&
        !body_call.receiver.is_a?(Fastererer::Primitive) &&
        body_call.receiver.name == method_call.block_argument_names.first
    end
  end
end
