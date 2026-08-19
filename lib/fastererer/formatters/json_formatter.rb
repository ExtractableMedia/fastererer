# frozen_string_literal: true

require 'json'
require_relative 'base'
require_relative '../version'

module Fastererer
  module Formatters
    # A single JSON document on stdout: metadata (tool version), summary (run counts),
    # and a flat offenses array. Diagnostics go to stderr so stdout is pure JSON.
    class JsonFormatter < Base
      def render(report)
        output_diagnostics(report)
        out.puts JSON.pretty_generate(document(report))
      end

      private

      def document(report)
        {
          'metadata' => { 'fastererer_version' => Fastererer::VERSION },
          'summary' => summary(report),
          'offenses' => offenses(report)
        }
      end

      def summary(report)
        {
          'offense_count' => report.offenses_detected_count,
          'inspected_file_count' => report.files_inspected_count,
          'unparsable_file_count' => report.unparsable_files.count
        }
      end

      def offenses(report)
        report.findings.sort_by { |finding| [finding.path, finding.line] }.map do |finding|
          {
            'path' => finding.path,
            'line' => finding.line,
            'rule' => finding.rule_name,
            'message' => finding.description,
            'url' => finding.url
          }
        end
      end
    end
  end
end
