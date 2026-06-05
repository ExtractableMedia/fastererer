# frozen_string_literal: true

require 'prism'
require 'fastererer/method_definition'
require 'fastererer/method_call'
require 'fastererer/rescue_call'
require 'fastererer/offense'
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
      root_node = Fastererer::Parser.parse(@file_content)
      root_node.accept(AnalyzerVisitor.new(errors))
    end

    def errors
      @errors ||= Fastererer::OffenseCollector.new
    end
  end

  class AnalyzerVisitor < Prism::Visitor
    def initialize(offenses)
      super()
      @offenses = offenses
    end

    def visit_call_node(node)
      collect(MethodCallScanner.new(node))
      super
    end

    def visit_def_node(node)
      collect(MethodDefinitionScanner.new(node))
      super
    end

    def visit_for_node(node)
      @offenses.push(Fastererer::Offense.new(:for_loop_vs_each, node.location.start_line))
      super
    end

    def visit_rescue_node(node)
      collect(RescueCallScanner.new(node))
      super
    end

    private

    def collect(scanner)
      @offenses.push(scanner.offense) if scanner.offense_detected?
    end
  end

  private_constant :AnalyzerVisitor
end
