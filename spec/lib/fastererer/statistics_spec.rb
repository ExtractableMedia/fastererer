# frozen_string_literal: true

require 'spec_helper'

describe Fastererer::Statistics do
  let(:report) do
    Fastererer::Report.new(findings: [], files_inspected_count: inspected_count,
                           offenses_detected_count: offenses_count,
                           unparsable_files: parse_errors, missing_path: nil)
  end

  let(:inspected_count) { 0 }
  let(:offenses_count) { 0 }
  let(:parse_errors) { [] }
  let(:statistics) { described_class.new(report) }

  describe 'inspected_files_output' do
    it 'includes the file count' do
      expect(statistics.inspected_files_output).to include('0 files inspected')
    end
  end

  describe 'unparsable_files_output' do
    context 'with no unparsable files' do
      it 'returns nil' do
        expect(statistics.unparsable_files_output).to be_nil
      end
    end

    context 'with unparsable files' do
      let(:parse_errors) { ['file.rb - ParseError - bad syntax'] }

      it 'includes the count' do
        expect(statistics.unparsable_files_output).to include('1 unparsable file found')
      end
    end

    context 'with multiple unparsable files' do
      let(:parse_errors) { ['a.rb - err', 'b.rb - err'] }

      it 'pluralizes correctly' do
        expect(statistics.unparsable_files_output).to include('2 unparsable files found')
      end
    end
  end

  describe '#to_s' do
    context 'with unparsable files' do
      let(:parse_errors) { ['file.rb - ParseError - bad syntax'] }

      it 'includes unparsable files in output' do
        expect(statistics.to_s).to include('unparsable')
      end
    end
  end

  describe 'pluralize' do
    it 'uses custom plural when provided' do
      result = statistics.send(:pluralize, 2, 'person', 'people')
      expect(result).to eq('people')
    end

    it 'uses singular for count of 1' do
      result = statistics.send(:pluralize, 1, 'file')
      expect(result).to eq('file')
    end
  end
end
