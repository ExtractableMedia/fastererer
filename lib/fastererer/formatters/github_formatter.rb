# frozen_string_literal: true

require_relative 'base'

module Fastererer
  module Formatters
    # Workflow commands the Actions runner turns into inline annotations, with no external tooling
    # The message names the rule key, not the display name — the key is what .fastererer.yml takes
    class GithubFormatter < Base
      def render(report)
        output_diagnostics(report)
        report.findings.each { |finding| out.puts(annotation(finding)) }
      end

      private

      def annotation(finding)
        "::warning file=#{property(finding.path)},line=#{finding.line}::#{message(finding)}"
      end

      def message(finding)
        percent_encode(sanitize("#{finding.rule_key}: #{finding.description}"))
      end

      # A comma or colon left raw would read as the end of the value, so both are encoded too
      def property(value)
        percent_encode(sanitize(value)).gsub(':', '%3A').gsub(',', '%2C')
      end

      # sanitize has already escaped the control characters, leaving the percent itself
      def percent_encode(text)
        text.gsub('%', '%25')
      end
    end
  end
end
