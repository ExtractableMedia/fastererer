# frozen_string_literal: true

require 'prism'
require 'fastererer/method_definition'
require 'fastererer/method_call'
require 'fastererer/rescue_call'
require 'fastererer/offense_collector'
require 'fastererer/parser'
require 'fastererer/scanners/method_call_scanner'
require 'fastererer/scanners/rescue_call_scanner'
require 'fastererer/scanners/method_definition_scanner'

module Fastererer
  class ParseError < StandardError; end

  class Analyzer
    attr_reader :file_path
    alias path file_path

    def initialize(file_path)
      @file_path = file_path.to_s
      @file_content = File.read(file_path)
    end

    def scan
      result = Fastererer::Parser.parse(@file_content)

      if result.failure?
        error = result.errors.first
        raise Fastererer::ParseError, error.message
      end

      visitor = AnalyzerVisitor.new(self)
      result.value.accept(visitor)
    end

    def errors
      @errors ||= Fastererer::OffenseCollector.new
    end

    # Internal callbacks invoked by AnalyzerVisitor during AST traversal.
    # Public only because AnalyzerVisitor is a separate class.

    def scan_method_definitions(node)
      scanner = MethodDefinitionScanner.new(node)
      errors.push(scanner.offense) if scanner.offense_detected?
    end

    def scan_method_calls(node)
      scanner = MethodCallScanner.new(node)
      errors.push(scanner.offense) if scanner.offense_detected?
    end

    def scan_for_loop(node)
      errors.push(Fastererer::Offense.new(:for_loop_vs_each, node.location.start_line))
    end

    def scan_rescue(node)
      scanner = RescueCallScanner.new(node)
      errors.push(scanner.offense) if scanner.offense_detected?
    end
  end

  class AnalyzerVisitor < Prism::Visitor
    def initialize(analyzer)
      super()
      @analyzer = analyzer
    end

    def visit_call_node(node)
      @analyzer.scan_method_calls(node)
      super
    end

    def visit_def_node(node)
      @analyzer.scan_method_definitions(node)
      super
    end

    def visit_for_node(node)
      @analyzer.scan_for_loop(node)
      super
    end

    def visit_rescue_node(node)
      @analyzer.scan_rescue(node)
      super
    end

    def visit_lambda_node(node)
      @analyzer.scan_method_calls(node)
      super
    end
  end
end
