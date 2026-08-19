# frozen_string_literal: true

require 'spec_helper'
require 'json'

describe Fastererer::Formatters::JsonFormatter do
  subject(:formatter) { described_class.new(out: out, err: err) }

  let(:out) { StringIO.new }
  let(:err) { StringIO.new }
  let(:document) { JSON.parse(out.string) }

  describe '#render' do
    context 'with offenses given out of order' do
      let(:findings) do
        [
          finding(path: 'b.rb', line: 9, rule_name: 'Performance/Bbb', description: 'Slow B'),
          finding(path: 'a.rb', line: 2, rule_name: 'Performance/Aaa', description: 'Slow A')
        ]
      end

      let(:expected_offenses) do
        [
          { 'path' => 'a.rb', 'line' => 2, 'rule' => 'Performance/Aaa',
            'message' => 'Slow A', 'url' => 'https://e.test' },
          { 'path' => 'b.rb', 'line' => 9, 'rule' => 'Performance/Bbb',
            'message' => 'Slow B', 'url' => 'https://e.test' }
        ]
      end

      before { formatter.render(report(findings: findings, inspected: 2)) }

      it 'reports the tool version under metadata' do
        expect(document['metadata']).to eq('fastererer_version' => Fastererer::VERSION)
      end

      it 'reports run counts under summary' do
        expect(document['summary']).to eq(
          'offense_count' => 2, 'inspected_file_count' => 2, 'unparsable_file_count' => 0
        )
      end

      it 'lists offenses sorted by path then line' do
        expect(document['offenses']).to eq(expected_offenses)
      end

      it 'ends stdout with a single trailing newline' do
        expect(out.string).to end_with("}\n")
      end
    end

    context 'with no offenses' do
      before { formatter.render(report(inspected: 3)) }

      it 'emits a valid document with an empty offenses array' do
        expect(document['offenses']).to eq([])
      end
    end

    context 'with unparsable files' do
      before { formatter.render(report(inspected: 1, unparsable: ['bad.rb - Err - boom'])) }

      it 'counts them under summary' do
        expect(document['summary']['unparsable_file_count']).to eq(1)
      end

      it 'routes their paths to stderr, keeping stdout pure JSON' do
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
