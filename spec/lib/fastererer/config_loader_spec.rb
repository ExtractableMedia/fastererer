# frozen_string_literal: true

require 'spec_helper'

describe Fastererer::ConfigLoader do
  include FileHelper

  include_context 'isolated environment'

  let(:path) { 'config.yml' }

  describe '.load' do
    context 'with speedups and exclude paths' do
      before do
        create_file(path, ['speedups:', '  gsub_vs_tr: false', 'exclude_paths:', "  - 'a'"])
      end

      it 'returns both sections' do
        expect(described_class.load(path))
          .to eq('speedups' => { 'gsub_vs_tr' => false }, 'exclude_paths' => ['a'])
      end
    end

    context 'with a new_speedups mode' do
      before { create_file(path, ['new_speedups: enable']) }

      it 'keeps the mode alongside the empty sections' do
        expect(described_class.load(path)['new_speedups']).to eq('enable')
      end
    end

    context 'with no new_speedups mode' do
      before { create_file(path, ['speedups:', '  gsub_vs_tr: false']) }

      it 'omits the key, so the default is inherited on merge' do
        expect(described_class.load(path)).not_to have_key('new_speedups')
      end
    end

    context 'with a blank file' do
      before { create_file(path, '') }

      it 'returns empty sections' do
        expect(described_class.load(path)).to eq('speedups' => {}, 'exclude_paths' => [])
      end
    end

    context 'with sections present but valueless' do
      before { create_file(path, ['speedups:', 'exclude_paths:']) }

      it 'returns empty sections' do
        expect(described_class.load(path)).to eq('speedups' => {}, 'exclude_paths' => [])
      end
    end

    context 'with a speedup entry carrying no value' do
      before { create_file(path, ['speedups:', '  gsub_vs_tr:']) }

      it 'drops the entry, so the default is inherited on merge' do
        expect(described_class.load(path)['speedups']).to be_empty
      end
    end

    context 'with a file that is not a mapping' do
      before { create_file(path, ['- one', '- two']) }

      it 'raises' do
        expect { described_class.load(path) }.to raise_error(Fastererer::ConfigError, /mapping/)
      end
    end

    context 'with a speedups section that is not a mapping' do
      before { create_file(path, ['speedups:', '  - gsub_vs_tr']) }

      it 'raises' do
        expect { described_class.load(path) }.to raise_error(Fastererer::ConfigError, /speedups/)
      end
    end

    context 'with an exclude_paths section that is not a list' do
      before { create_file(path, ['exclude_paths: tmp/*.rb']) }

      it 'raises' do
        expect { described_class.load(path) }.to raise_error(Fastererer::ConfigError, /array/)
      end
    end

    context 'with no file at the given path' do
      it 'raises' do
        expect { described_class.load(path) }.to raise_error(Fastererer::ConfigError, /not found/)
      end
    end

    context 'with invalid YAML' do
      before { create_file(path, ['speedups: [unclosed']) }

      it 'raises' do
        expect { described_class.load(path) }.to raise_error(Fastererer::ConfigError, /valid YAML/)
      end
    end

    context 'with a YAML type outside the safe set' do
      before { create_file(path, [':speedups: 1']) }

      it 'raises' do
        expect { described_class.load(path) }.to raise_error(Fastererer::ConfigError, /YAML type/)
      end
    end
  end
end
