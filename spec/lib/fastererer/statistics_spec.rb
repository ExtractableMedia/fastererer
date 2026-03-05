# frozen_string_literal: true

require 'spec_helper'

describe Fastererer::Statistics do
  let(:traverser_mock) do
    Struct.new(:scannable_files, :offenses_total_count, :parse_error_paths)
          .new(scannable_files, offenses_count, parse_errors)
  end

  let(:scannable_files) { [] }
  let(:offenses_count) { 0 }
  let(:parse_errors) { [] }
  let(:statistics) { described_class.new(traverser_mock) }

  describe 'inspected_files_output' do
    it 'is green' do
      expect(statistics.inspected_files_output).to eq("\e[32m0 files inspected\e[0m")
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

      it 'returns red output with count' do
        expect(statistics.unparsable_files_output).to eq("\e[31m1 unparsable file found\e[0m")
      end
    end

    context 'with multiple unparsable files' do
      let(:parse_errors) { ['a.rb - err', 'b.rb - err'] }

      it 'pluralizes correctly' do
        expect(statistics.unparsable_files_output).to eq("\e[31m2 unparsable files found\e[0m")
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
