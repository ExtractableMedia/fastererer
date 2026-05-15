# frozen_string_literal: true

require 'fastererer/method_definition'
require 'fastererer/method_call'
require 'fastererer/rescue_call'
require 'fastererer/offense_collector'
require 'fastererer/parser'
require 'fastererer/scanners/method_call_scanner'
require 'fastererer/scanners/rescue_call_scanner'
require 'fastererer/scanners/method_definition_scanner'

module Fastererer
  class Analyzer
    attr_reader :file_path
    alias path file_path

    def initialize(file_path)
      @file_path = file_path.to_s
      @file_content = File.read(file_path)
    end

    def scan
      sexp_tree = Fastererer::Parser.parse(@file_content)
      traverse_sexp_tree(sexp_tree)
    end

    def errors
      @errors ||= Fastererer::OffenseCollector.new
    end

    private

    def traverse_sexp_tree(sexp_tree)
      return unless sexp_tree.is_a?(Sexp)

      token = sexp_tree.first

      scan_by_token(token, sexp_tree)

      case token
      when :call, :iter
        method_call = MethodCall.new(sexp_tree)
        traverse_sexp_tree(method_call.receiver_element) if method_call.receiver_element
        traverse_sexp_tree(method_call.arguments_element)
        traverse_sexp_tree(method_call.block_body) if method_call.block?
      else
        sexp_tree.each { |element| traverse_sexp_tree(element) }
      end
    end

    def scan_by_token(token, element)
      case token
      when :defn
        scan_method_definitions(element)
      when :call, :iter
        scan_method_calls(element)
      when :for
        scan_for_loop(element)
      when :resbody
        scan_rescue(element)
      end
    end

    def scan_method_definitions(element)
      method_definition_scanner = MethodDefinitionScanner.new(element)

      return unless method_definition_scanner.offense_detected?

      errors.push(method_definition_scanner.offense)
    end

    def scan_method_calls(element)
      method_call_scanner = MethodCallScanner.new(element)

      return unless method_call_scanner.offense_detected?

      errors.push(method_call_scanner.offense)
    end

    def scan_for_loop(element)
      errors.push(Fastererer::Offense.new(:for_loop_vs_each, element.line))
    end

    def scan_rescue(element)
      rescue_call_scanner = RescueCallScanner.new(element)

      return unless rescue_call_scanner.offense_detected?

      errors.push(rescue_call_scanner.offense)
    end
  end
end
