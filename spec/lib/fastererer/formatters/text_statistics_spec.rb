# frozen_string_literal: true

require 'spec_helper'

describe Fastererer::Formatters::TextStatistics do
  let(:report) do
    Fastererer::Report.new(findings: findings, files_inspected_count: inspected_count,
                           unparsable_files: parse_errors, missing_path: nil)
  end

  let(:findings) { [] }
  let(:inspected_count) { 0 }
  let(:parse_errors) { [] }
  let(:statistics) { described_class.new(report) }

  describe '#to_s' do
    context 'with unparsable files' do
      let(:parse_errors) { ['file.rb - ParseError - bad syntax'] }

      it 'includes unparsable files in output' do
        expect(statistics.to_s).to include('unparsable')
      end
    end
  end

  describe '#inspected_files_output' do
    it 'includes the file count' do
      expect(statistics.inspected_files_output).to include('0 files inspected')
    end
  end

  describe '#offenses_detected_output' do
    context 'with no offenses' do
      it 'reports the count in the singular-free form' do
        expect(statistics.offenses_detected_output).to include('0 offenses detected')
      end
    end

    context 'with one offense' do
      let(:findings) { [instance_double(Fastererer::Finding)] }

      it 'reports the count in the singular' do
        expect(statistics.offenses_detected_output).to include('1 offense detected')
      end
    end
  end

  describe '#unparsable_files_output' do
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

  describe '#pluralize' do
    it 'uses singular for count of 1' do
      expect(statistics.pluralize(1, 'file')).to eq('file')
    end
  end
end
