# frozen_string_literal: true

require 'spec_helper'
require 'json'

describe Fastererer::Formatters::RdjsonlFormatter do
  include FormatterHelpers

  subject(:formatter) { described_class.new(out: out, err: err) }

  let(:out) { StringIO.new }
  let(:err) { StringIO.new }
  let(:lines) { out.string.lines }

  describe '#render' do
    context 'with offenses' do
      let(:findings) do
        [finding(path: 'a.rb', line: 2, rule_key: 'aaa', description: 'Slow A'),
         finding(path: 'a.rb', line: 7, rule_key: 'bbb', description: 'Slow B'),
         finding(path: 'b.rb', line: 9, rule_key: 'aaa', description: 'Slow C')]
      end

      let(:expected_locations) do
        [{ 'path' => 'a.rb', 'range' => { 'start' => { 'line' => 2 } } },
         { 'path' => 'a.rb', 'range' => { 'start' => { 'line' => 7 } } },
         { 'path' => 'b.rb', 'range' => { 'start' => { 'line' => 9 } } }]
      end

      let(:expected_diagnostic) do
        {
          'message' => 'Slow A',
          'location' => { 'path' => 'a.rb', 'range' => { 'start' => { 'line' => 2 } } },
          'severity' => 'WARNING',
          'code' => { 'value' => 'aaa', 'url' => 'https://e.test' }
        }
      end

      before { formatter.render(report(findings: findings, inspected: 2)) }

      it 'emits one JSON record per offense' do
        expect(lines.count).to eq(3)
      end

      it 'emits a record for every offense, including repeats within one file' do
        locations = lines.map { |line| JSON.parse(line).fetch('location') }

        expect(locations).to eq(expected_locations)
      end

      it 'matches the reviewdog Diagnostic shape' do
        expect(JSON.parse(lines.first)).to eq(expected_diagnostic)
      end

      it 'excludes the statistics line' do
        expect(out.string).not_to include('files inspected')
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
end
