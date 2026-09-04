# frozen_string_literal: true

module Fastererer
  module Formatters
    class Base
      # The gap at \x09 keeps tabs, which are printable, out of the escaping
      UNSAFE_CHARS = /[\x00-\x08\x0A-\x1F\x7F]/
      private_constant :UNSAFE_CHARS

      def initialize(out: $stdout, err: $stderr)
        @out = out
        @err = err
      end

      private

      attr_reader :out, :err

      # Undecorated on purpose for the machine formats; TextFormatter overrides with color
      def output_diagnostics(report)
        missing_path = report.missing_path

        err.puts("No such file or directory - #{sanitize(missing_path)}") if missing_path
        report.unparsable_files.each { |unparsable_file| err.puts(sanitize(unparsable_file.to_s)) }
      end

      def sanitize(text)
        text.to_s.scrub.gsub(UNSAFE_CHARS) { |char| format('\\x%02X', char.ord) }
      end
    end
  end
end
