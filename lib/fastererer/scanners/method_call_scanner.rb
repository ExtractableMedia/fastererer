# frozen_string_literal: true

require 'fastererer/method_call'
require 'fastererer/offense'
require 'fastererer/scanners/offensive'
require 'fastererer/scanners/symbol_to_proc_check'

module Fastererer
  class MethodCallScanner
    include Fastererer::Offensive
    include Fastererer::SymbolToProcCheck

    CHECKERS = {
      module_eval: :check_module_eval_offense,
      gsub: :check_gsub_offense,
      sort: :check_sort_offense,
      each_with_index: :check_each_with_index_offense,
      first: :check_first_offense,
      each: :check_each_offense,
      flatten: :check_flatten_offense,
      fetch: :check_fetch_offense,
      merge!: :check_merge_bang_offense,
      last: :check_last_offense,
      include?: :check_range_include_offense
    }.freeze
    private_constant :CHECKERS

    attr_reader :element

    def initialize(element)
      @element = element
      check_offense
    end

    def method_call
      @method_call ||= MethodCall.new(element)
    end

    private

    def check_offense
      checker = CHECKERS[method_call.method_name]
      send(checker) if checker
      check_symbol_to_proc
    end

    def check_module_eval_offense
      first_argument = method_call.arguments.first
      return unless first_argument && first_argument.value.is_a?(String)

      add_offense(:module_eval) if first_argument.value.include?('def')
    end

    def check_gsub_offense
      first_argument = method_call.arguments[0]
      second_argument = method_call.arguments[1]
      return if first_argument.nil? || second_argument.nil?

      add_offense(:gsub_vs_tr) if both_single_char_strings?(first_argument, second_argument)
    end

    def both_single_char_strings?(first, second)
      [first, second].all? { |arg| arg.value.is_a?(String) && arg.value.size == 1 }
    end

    def check_sort_offense
      return unless method_call.arguments.any? || method_call.block?

      add_offense(:sort_vs_sort_by)
    end

    def check_each_with_index_offense
      add_offense(:each_with_index_vs_while)
    end

    def check_first_offense
      return unless method_call.receiver.is_a?(MethodCall)

      case method_call.receiver.name
      when :shuffle
        add_offense(:shuffle_first_vs_sample)
      when :select
        return unless method_call.receiver.block?
        return if method_call.arguments.any?

        add_offense(:select_first_vs_detect)
      end
    end

    def check_each_offense
      return unless method_call.receiver.is_a?(MethodCall)

      case method_call.receiver.name
      when :reverse
        add_offense(:reverse_each_vs_reverse_each)
      when :keys
        add_offense(:keys_each_vs_each_key) if method_call.receiver.arguments.none?
      end
    end

    def check_flatten_offense
      return unless method_call.receiver.is_a?(MethodCall)
      return unless method_call.receiver.name == :map && method_call.arguments.one?

      add_offense(:map_flatten_vs_flat_map) if method_call.arguments.first.value == 1
    end

    def check_fetch_offense
      return unless method_call.arguments.count == 2 && !method_call.block?

      add_offense(:fetch_with_argument_vs_block)
    end

    def check_merge_bang_offense
      return unless method_call.arguments.one?

      first_argument = method_call.arguments.first
      return unless first_argument.type == :hash
      # each key and value is an item by itself.
      return unless first_argument.element.drop(1).count == 2

      add_offense(:hash_merge_bang_vs_hash_brackets)
    end

    def check_last_offense
      return unless method_call.receiver.is_a?(MethodCall)
      return unless method_call.receiver.name == :select
      return if method_call.arguments.any?

      add_offense(:select_last_vs_reverse_detect)
    end

    def check_range_include_offense
      return unless method_call.receiver.is_a?(Primitive) && method_call.receiver.range?

      add_offense(:include_vs_cover_on_range)
    end
  end
end
