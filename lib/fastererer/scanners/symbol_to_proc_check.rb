# frozen_string_literal: true

require 'fastererer/method_call'

module Fastererer
  # Includer must respond to #method_call (returning a MethodCall) and #add_offense(symbol).
  module SymbolToProcCheck
    private

    def check_symbol_to_proc
      return unless symbol_to_proc_candidate?

      body_call = MethodCall.new(method_call.block_body)
      return unless symbol_to_proc_body?(body_call)

      add_offense(:block_vs_symbol_to_proc)
    end

    def symbol_to_proc_candidate?
      method_call.block_argument_names.one? &&
        !method_call.block_body.nil? &&
        method_call.block_body.sexp_type == :call &&
        method_call.arguments.none? &&
        !method_call.lambda_literal?
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
