# frozen_string_literal: true

# Builds the value objects a formatter renders, without running a scan
module FormatterHelpers
  def finding(path:, line:, description:, rule_key: 'slow_thing',
              rule_name: 'Performance/SlowThing', url: 'https://e.test')
    Fastererer::Finding.new(path:, line:, rule_key:, rule_name:, description:, url:)
  end

  def report(findings: [], inspected: 0, unparsable: [], missing: nil)
    Fastererer::Report.new(findings:, files_inspected_count: inspected,
                           unparsable_files: unparsable, missing_path: missing)
  end
end
