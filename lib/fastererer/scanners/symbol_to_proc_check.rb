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
      single_block_argument_name &&
        single_call_body? &&
        method_call.arguments.none? &&
        !method_call.lambda_literal?
    end

    # A destructured param has no name, so |(a, b), c| must not read as a single-name block
    def single_block_argument_name
      names = method_call.block_argument_names
      names.first if names.size == 1
    end

    # A safe-nav body (foo&.bar) is excluded: arr.map(&:bar) raises on a nil element, so the rewrite
    # would not preserve behavior
    def single_call_body?
      body = method_call.block_body
      body&.size == 1 && body.first.is_a?(Prism::CallNode) && !body.first.safe_navigation?
    end

    # A primitive receiver's name is nil, which never matches the named param the gate requires
    def symbol_to_proc_body?(body_call)
      body_call.arguments.none? &&
        !body_call.block? &&
        body_call.receiver&.name == single_block_argument_name
    end
  end
end
