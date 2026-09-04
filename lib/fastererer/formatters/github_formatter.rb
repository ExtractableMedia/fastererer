# frozen_string_literal: true

require_relative 'base'

module Fastererer
  module Formatters
    # Workflow commands the Actions runner turns into inline annotations, with no external tooling
    # The message names the rule key, not the display name — the key is what .fastererer.yml takes
    class GithubFormatter < Base
      PROPERTY_ESCAPES = { '%' => '%25', ':' => '%3A', ',' => '%2C' }.freeze
      private_constant :PROPERTY_ESCAPES

      def render(report)
        output_diagnostics(report)
        report.findings.each { |finding| out.puts(annotation(finding)) }
      end

      private

      def annotation(finding)
        "::warning file=#{property(finding.path)},line=#{finding.line}::#{message(finding)}"
      end

      # sanitize has already escaped the control characters, leaving the percent itself
      def message(finding)
        sanitize("#{finding.rule_key}: #{finding.description}").gsub('%', '%25')
      end

      # A comma or colon would end the value, and one pass never re-encodes the percent it emits
      def property(value)
        sanitize(value).gsub(/[%:,]/, PROPERTY_ESCAPES)
      end
    end
  end
end
