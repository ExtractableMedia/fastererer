# frozen_string_literal: true

module Fastererer
  # Everything the formatters render: the speedup-filtered findings plus run counts
  # and the boundary conditions (unparsable files, a missing path). Constructible in
  # isolation so formatters can be unit-tested without a scan.
  Report = Struct.new(
    :findings,
    :files_inspected_count,
    :offenses_detected_count,
    :unparsable_files,
    :missing_path,
    keyword_init: true
  )
end
