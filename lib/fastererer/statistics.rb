# frozen_string_literal: true

require_relative 'painter'

module Fastererer
  # Renders the human-readable run summary line for the text format.
  class Statistics
    def initialize(report)
      @files_inspected_count  = report.files_inspected_count
      @offenses_found_count   = report.offenses_detected_count
      @unparsable_files_count = report.unparsable_files.count
    end

    def to_s
      [
        inspected_files_output,
        offenses_found_output,
        unparsable_files_output
      ].compact.join(', ')
    end

    def inspected_files_output
      Painter.paint(
        "#{@files_inspected_count} #{pluralize(@files_inspected_count, 'file')} inspected", :green
      )
    end

    def offenses_found_output
      color = @offenses_found_count.zero? ? :green : :red

      Painter.paint(
        "#{@offenses_found_count} #{pluralize(@offenses_found_count, 'offense')} detected", color
      )
    end

    def unparsable_files_output
      return if @unparsable_files_count.zero?

      Painter.paint(
        "#{@unparsable_files_count} unparsable #{pluralize(@unparsable_files_count, 'file')} found",
        :red
      )
    end

    def pluralize(count, singular, plural = nil)
      if count == 1
        singular.to_s
      elsif plural
        plural.to_s
      else
        "#{singular}s"
      end
    end
  end
end
