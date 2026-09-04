# frozen_string_literal: true

require 'spec_helper'
require 'json'

describe Fastererer::Formatters::JsonFormatter do
  include FormatterHelpers

  subject(:formatter) { described_class.new(out: out, err: err) }

  let(:out) { StringIO.new }
  let(:err) { StringIO.new }
  let(:document) { JSON.parse(out.string) }

  describe '#render' do
    context 'with offenses given out of order' do
      let(:findings) do
        [finding(path: 'b.rb', line: 9, rule_name: 'Performance/Bbb', description: 'Slow B',
                 rule_key: 'bbb'),
         finding(path: 'a.rb', line: 2, rule_name: 'Performance/Aaa', description: 'Slow A',
                 rule_key: 'aaa')]
      end

      let(:expected_offenses) do
        [
          { 'path' => 'a.rb', 'line' => 2, 'rule' => 'Performance/Aaa', 'rule_key' => 'aaa',
            'message' => 'Slow A', 'url' => 'https://e.test' },
          { 'path' => 'b.rb', 'line' => 9, 'rule' => 'Performance/Bbb', 'rule_key' => 'bbb',
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

    context 'with a missing path' do
      before { formatter.render(report(inspected: 1, missing: 'nope.rb')) }

      it 'routes the missing-path message to stderr' do
        expect(err.string).to eq("No such file or directory - nope.rb\n")
      end

      it 'keeps stdout pure JSON' do
        expect(document['summary']['inspected_file_count']).to eq(1)
      end
    end

    context 'with a control character in a diagnostic path' do
      let(:unparsable) { "ev\e[31mIL.rb - Err - boom" }

      before do
        formatter.render(report(inspected: 1, missing: "no\e[31mpe", unparsable: [unparsable]))
      end

      it 'escapes control bytes instead of letting them reach the terminal', :aggregate_failures do
        expect(err.string).to include('no\\x1B[31mpe')
        expect(err.string).not_to include("\e")
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
end
