# frozen_string_literal: true

require 'spec_helper'
require 'json'

describe Fastererer::Formatters::RdjsonlFormatter do
  subject(:formatter) { described_class.new(out: out, err: err) }

  let(:out) { StringIO.new }
  let(:err) { StringIO.new }
  let(:lines) { out.string.lines }

  describe '#render' do
    context 'with offenses' do
      let(:findings) do
        [
          finding(path: 'a.rb', line: 2, rule_name: 'Performance/Aaa', description: 'Slow A'),
          finding(path: 'b.rb', line: 9, rule_name: 'Performance/Bbb', description: 'Slow B')
        ]
      end

      let(:expected_diagnostic) do
        {
          'message' => 'Slow A',
          'location' => { 'path' => 'a.rb', 'range' => { 'start' => { 'line' => 2 } } },
          'severity' => 'WARNING',
          'code' => { 'value' => 'Performance/Aaa', 'url' => 'https://e.test' }
        }
      end

      before { formatter.render(report(findings: findings, inspected: 2)) }

      it 'emits one JSON record per offense' do
        expect(lines.count).to eq(2)
      end

      it 'matches the reviewdog Diagnostic shape' do
        expect(JSON.parse(lines.first)).to eq(expected_diagnostic)
      end

      it 'excludes statistics' do
        expect(out.string).not_to include('summary')
      end
    end

    context 'with no offenses' do
      before { formatter.render(report(inspected: 3)) }

      it 'writes zero bytes to stdout' do
        expect(out.string).to be_empty
      end
    end

    context 'with unparsable files' do
      before { formatter.render(report(inspected: 1, unparsable: ['bad.rb - Err - boom'])) }

      it 'routes them to stderr, keeping stdout clean' do
        expect(err.string).to include('bad.rb - Err - boom')
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
