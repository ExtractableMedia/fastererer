# frozen_string_literal: true

require_relative 'base'
require_relative '../painter'
require_relative '../statistics'
require_relative '../explanation'

module Fastererer
  module Formatters
    # The default human-readable format. Offenses and the statistics line go to stdout;
    # diagnostics go to stderr. Renders via Explanation.format_line so the offense line
    # stays byte-for-byte identical to the pre-formatter output.
    class TextFormatter < Base
      def render(report)
        output_offenses(report)
        output_diagnostics(report)
        output_statistics(report)
      end

      private

      def output_offenses(report)
        report.findings.group_by(&:path).each do |path, path_findings|
          path_findings.group_by(&:rule_name).each_value do |group|
            output_group(path, group)
          end
          out.puts
        end
      end

      def output_group(path, group)
        first = group.first
        line = Explanation.format_line(first.rule_name, first.description, first.url)

        group.each do |finding|
          location = Painter.paint("#{path}:#{finding.line}", :red)
          out.puts "#{location}: #{severity}: #{line}"
        end
      end

      def output_diagnostics(report)
        output_missing_path(report)
        output_parse_errors(report)
      end

      def output_missing_path(report)
        return unless report.missing_path

        err.puts Painter.paint("No such file or directory - #{report.missing_path}", :red)
      end

      def output_parse_errors(report)
        return if report.unparsable_files.none?

        err.puts 'Fastererer was unable to process some files. Unprocessable files were:'
        err.puts '-----------------------------------------------------'
        err.puts report.unparsable_files
        err.puts
      end

      def output_statistics(report)
        out.puts Statistics.new(report)
      end

      def severity
        @severity ||= Painter.paint('W', :magenta)
      end
    end
  end
end
