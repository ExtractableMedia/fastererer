# frozen_string_literal: true

require_relative '../painter'
require_relative 'text_statistics'
require_relative '../explanation'

module Fastererer
  module Formatters
    class TextFormatter
      # The gap at \x09 keeps tabs, which are printable, out of the escaping
      UNSAFE_CHARS = /[\x00-\x08\x0A-\x1F\x7F]/
      private_constant :UNSAFE_CHARS

      def initialize(out: $stdout, err: $stderr)
        @out = out
        @err = err
      end

      def render(report)
        output_offenses(report)
        output_diagnostics(report)
        output_statistics(report)
      end

      private

      attr_reader :out, :err

      def output_offenses(report)
        report.findings.group_by(&:path).each_value do |path_findings|
          path_findings.group_by(&:rule_name).each_value { |group| output_group(group) }
          out.puts
        end
      end

      def output_group(group)
        group.each do |finding|
          location = Painter.paint("#{sanitize(finding.path)}:#{finding.line}", :red)
          out.puts "#{location}: #{severity}: #{Explanation.format_line(finding)}"
        end
      end

      def output_diagnostics(report)
        output_missing_path(report)
        output_parse_errors(report)
      end

      def output_missing_path(report)
        return unless report.missing_path

        message = "No such file or directory - #{sanitize(report.missing_path)}"
        err.puts Painter.paint(message, :red)
      end

      def output_parse_errors(report)
        return if report.unparsable_files.none?

        err.puts 'Fastererer was unable to process some files. Unprocessable files were:'
        err.puts '-----------------------------------------------------'
        report.unparsable_files.each { |unparsable_file| err.puts sanitize(unparsable_file.to_s) }
        err.puts
      end

      def output_statistics(report)
        out.puts TextStatistics.new(report)
      end

      def sanitize(text)
        text.to_s.scrub.gsub(UNSAFE_CHARS) { |char| format('\\x%02X', char.ord) }
      end

      def severity
        @severity ||= Painter.paint('W', :magenta)
      end
    end
  end
end
