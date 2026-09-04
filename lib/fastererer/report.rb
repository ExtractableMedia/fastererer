# frozen_string_literal: true

module Fastererer
  # Findings arrive already filtered by ignored speedups; formatters must not filter again
  Report = Data.define(:findings, :files_inspected_count, :unparsable_files, :missing_path) do
    def offenses_detected_count
      findings.count
    end
  end
end
