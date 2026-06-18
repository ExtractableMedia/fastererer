# frozen_string_literal: true

module Fastererer
  module Formatters
    # Shared composition root for output streams. Subclasses own #render. The default
    # diagnostics routing (missing path + unparsable files to stderr) suits the machine
    # formats; TextFormatter overrides it with a decorated, colored block.
    class Base
      def initialize(out: $stdout, err: $stderr)
        @out = out
        @err = err
      end

      private

      attr_reader :out, :err

      def output_diagnostics(report)
        err.puts("No such file or directory - #{report.missing_path}") if report.missing_path
        report.unparsable_files.each { |line| err.puts(line) }
      end
    end
  end
end
