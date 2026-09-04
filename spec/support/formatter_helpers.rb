# frozen_string_literal: true

# Builds the value objects a formatter renders, without running a scan
module FormatterHelpers
  def finding(path:, line:, rule_name:, description:, url: 'https://e.test',
              rule_key: 'slow_thing')
    Fastererer::Finding.new(path:, line:, rule_key:, rule_name:, description:, url:)
  end

  def report(findings: [], inspected: 0, unparsable: [], missing: nil)
    Fastererer::Report.new(findings:, files_inspected_count: inspected,
                           unparsable_files: unparsable, missing_path: missing)
  end
end
