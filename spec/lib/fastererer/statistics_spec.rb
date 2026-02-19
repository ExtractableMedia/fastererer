require 'spec_helper'

describe Fastererer::Statistics do
  let(:traverser_mock) do
    Struct.new(:scannable_files, :offenses_total_count, :parse_error_paths).new([], 0, [])
  end

  let(:statistics) { Fastererer::Statistics.new(traverser_mock) }

  describe 'inspected_files_output' do
    it 'should be green' do
      expect(statistics.inspected_files_output).to eq("\e[32m0 files inspected\e[0m")
    end
  end
end
