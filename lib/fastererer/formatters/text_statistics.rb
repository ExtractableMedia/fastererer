# frozen_string_literal: true

require_relative '../painter'

module Fastererer
  module Formatters
    class TextStatistics
      def initialize(report)
        @files_inspected_count   = report.files_inspected_count
        @offenses_detected_count = report.offenses_detected_count
        @unparsable_files_count  = report.unparsable_files.count
      end

      def to_s
        [inspected_files_output, offenses_detected_output, unparsable_files_output]
          .compact.join(', ')
      end

      def inspected_files_output
        count = @files_inspected_count

        Painter.paint("#{count} #{pluralize(count, 'file')} inspected", :green)
      end

      def offenses_detected_output
        count = @offenses_detected_count
        color = count.zero? ? :green : :red

        Painter.paint("#{count} #{pluralize(count, 'offense')} detected", color)
      end

      def unparsable_files_output
        return if @unparsable_files_count.zero?

        count = @unparsable_files_count

        Painter.paint("#{count} unparsable #{pluralize(count, 'file')} found", :red)
      end

      def pluralize(count, singular)
        count == 1 ? singular : "#{singular}s"
      end
    end
  end
end
