# frozen_string_literal: true

require 'spec_helper'

describe Fastererer::DefaultConfig do
  describe '.load' do
    let(:defaults) { described_class.load }

    it 'enables every speedup the rule catalog knows about' do
      expect(defaults['speedups'].keys).to match_array(Fastererer::RuleCatalog.all.keys)
    end

    it 'excludes the Ruby-level directories a project never wants scanned' do
      expect(defaults['exclude_paths'])
        .to contain_exactly('tmp/**/*.rb', 'vendor/**/*.rb', 'node_modules/**/*.rb')
    end

    it 'holds new speedups back until a project opts in' do
      expect(defaults['new_speedups']).to eq('warn')
    end

    it 'freezes nested values, so a merged copy cannot mutate the defaults' do
      expect(defaults['speedups']).to be_frozen
    end

    it 'freezes list entries too' do
      expect(defaults['exclude_paths'].first).to be_frozen
    end
  end
end
