# frozen_string_literal: true

require 'json'
require_relative 'base'

module Fastererer
  module Formatters
    # Reviewdog Diagnostic Format, one JSON object per line (rdjsonl). No statistics.
    # Pinned to the RDFormat schema: WARNING severity, flat code.url, start-only range.
    class RdjsonlFormatter < Base
      SEVERITY = 'WARNING'

      def render(report)
        output_diagnostics(report)
        report.findings.each { |finding| out.puts JSON.generate(diagnostic(finding)) }
      end

      private

      def diagnostic(finding)
        {
          'message' => finding.description,
          'location' => {
            'path' => finding.path,
            'range' => { 'start' => { 'line' => finding.line } }
          },
          'severity' => SEVERITY,
          'code' => { 'value' => finding.rule_name, 'url' => finding.url }
        }
      end
    end
  end
end
