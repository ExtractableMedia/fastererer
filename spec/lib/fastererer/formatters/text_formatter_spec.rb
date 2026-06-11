# frozen_string_literal: true

require 'spec_helper'

describe Fastererer::Formatters::TextFormatter do
  subject(:formatter) { described_class.new(out: out, err: err) }

  let(:out) { StringIO.new }
  let(:err) { StringIO.new }

  before { Fastererer::Painter.disable! }

  after { Fastererer::Painter.enable! }

  describe '#render' do
    context 'with offenses across files and rules' do
      let(:findings) do
        [
          finding(path: 'a.rb', line: 1, rule_name: 'Performance/Aaa', description: 'Slow A'),
          finding(path: 'a.rb', line: 2, rule_name: 'Performance/Aaa', description: 'Slow A'),
          finding(path: 'a.rb', line: 3, rule_name: 'Performance/Bbb', description: 'Slow B'),
          finding(path: 'b.rb', line: 5, rule_name: 'Performance/Aaa', description: 'Slow A')
        ]
      end

      let(:expected_output) do
        <<~OUTPUT
          a.rb:1: W: Performance/Aaa: Slow A. (https://e.test)
          a.rb:2: W: Performance/Aaa: Slow A. (https://e.test)
          a.rb:3: W: Performance/Bbb: Slow B. (https://e.test)

          b.rb:5: W: Performance/Aaa: Slow A. (https://e.test)

          4 files inspected, 4 offenses detected
        OUTPUT
      end

      before { formatter.render(report(findings: findings, inspected: 4)) }

      it 'groups by file then rule, blank line per file, then statistics on stdout' do
        expect(out.string).to eq(expected_output)
      end

      it 'writes nothing to stderr' do
        expect(err.string).to be_empty
      end
    end

    context 'with a missing path' do
      before { formatter.render(report(inspected: 1, missing: 'nope.rb')) }

      it 'routes the missing-path message to stderr' do
        expect(err.string).to eq("No such file or directory - nope.rb\n")
      end

      it 'keeps stdout to the statistics line only' do
        expect(out.string).to eq("1 file inspected, 0 offenses detected\n")
      end
    end

    context 'with unparsable files' do
      before { formatter.render(report(inspected: 1, unparsable: ['bad.rb - Err - boom'])) }

      it 'routes the parse-error block to stderr' do
        expect(err.string)
          .to include('Unprocessable files were:').and(include('bad.rb - Err - boom'))
      end

      it 'keeps the offense payload off stderr-bound stdout' do
        expect(out.string).to eq("1 file inspected, 0 offenses detected, 1 unparsable file found\n")
      end
    end
  end

  def finding(path:, line:, rule_name:, description:, url: 'https://e.test')
    Fastererer::Finding.new(path: path, line: line, rule_name: rule_name,
                            description: description, url: url)
  end

  def report(findings: [], inspected: 0, unparsable: [], missing: nil)
    Fastererer::Report.new(findings: findings, files_inspected_count: inspected,
                           offenses_detected_count: findings.count,
                           unparsable_files: unparsable, missing_path: missing)
  end
end
