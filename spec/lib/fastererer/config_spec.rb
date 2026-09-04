# frozen_string_literal: true

require 'spec_helper'
require 'pathname'

describe Fastererer::Config do
  include FileHelper

  let(:root) { Pathname.new("#{File.dirname(__FILE__)}/../../..").cleanpath }
  let(:expected_location) { "#{root}/.fastererer.yml" }

  describe '#ignored_speedups' do
    include_context 'isolated environment'

    context 'with a speedup the project file switches off' do
      before { create_file(described_class::FILE_NAME, ['speedups:', '  gsub_vs_tr: false']) }

      it 'ignores it' do
        expect(described_class.new.ignored_speedups).to contain_exactly(:gsub_vs_tr)
      end
    end

    context 'with a speedup the project file leaves on' do
      before { create_file(described_class::FILE_NAME, ['speedups:', '  gsub_vs_tr: true']) }

      it 'does not ignore it' do
        expect(described_class.new.ignored_speedups).not_to include(:gsub_vs_tr)
      end
    end

    context 'with a speedup the project file does not mention' do
      before { create_file(described_class::FILE_NAME, ['speedups:', '  sort_vs_sort_by: false']) }

      it 'keeps the shipped default, leaving it enabled' do
        expect(described_class.new.ignored_speedups).not_to include(:gsub_vs_tr)
      end
    end

    context 'with a speedup key carrying no value' do
      before { create_file(described_class::FILE_NAME, ['speedups:', '  gsub_vs_tr:']) }

      it 'inherits the shipped default rather than reading the nil as off' do
        expect(described_class.new.ignored_speedups).not_to include(:gsub_vs_tr)
      end
    end

    context 'with a non-boolean speedup value' do
      before { create_file(described_class::FILE_NAME, ['speedups:', '  gsub_vs_tr: yes please']) }

      it 'leaves it enabled, because only false switches a speedup off' do
        expect(described_class.new.ignored_speedups).not_to include(:gsub_vs_tr)
      end
    end

    context 'with no project config file' do
      it 'ignores nothing' do
        expect(described_class.new.ignored_speedups).to be_empty
      end
    end
  end

  describe '#ignored_files' do
    include_context 'isolated environment'

    before { create_file('vendor/gem.rb') }

    context 'with no project config file' do
      it 'globs the shipped default excludes' do
        expect(described_class.new.ignored_files).to contain_exactly('vendor/gem.rb')
      end
    end

    context 'with project exclude paths' do
      before do
        create_file(described_class::FILE_NAME, ['exclude_paths:', "  - 'app/*.rb'"])
        create_file('app/user.rb')
      end

      it 'globs the project paths alongside the defaults' do
        expect(described_class.new.ignored_files).to contain_exactly('vendor/gem.rb', 'app/user.rb')
      end
    end
  end

  describe '#file' do
    include_context 'isolated environment'

    context 'with no project config file' do
      it 'returns the shipped defaults verbatim' do
        expect(described_class.new.file).to eq(Fastererer::DefaultConfig.load)
      end

      it 'memoizes the result across calls' do
        config = described_class.new
        expect(config.file).to equal(config.file)
      end
    end

    context 'with a blank project config file' do
      before { create_file(described_class::FILE_NAME, '') }

      it 'falls back to the shipped defaults' do
        expect(described_class.new.file).to eq(Fastererer::DefaultConfig.load)
      end
    end

    context 'with a speedups key carrying no value' do
      before { create_file(described_class::FILE_NAME, ['speedups:']) }

      it 'keeps every shipped speedup' do
        expect(described_class.new.file[described_class::SPEEDUPS_KEY]).to eq(default_speedups)
      end
    end

    context 'with an exclude_paths key carrying no value' do
      before { create_file(described_class::FILE_NAME, ['exclude_paths:']) }

      it 'keeps the shipped excludes' do
        expect(described_class.new.file[described_class::EXCLUDE_PATHS_KEY]).to eq(default_excludes)
      end
    end

    context 'with a speedup the project file overrides' do
      before { create_file(described_class::FILE_NAME, ['speedups:', '  gsub_vs_tr: false']) }

      it 'lets the project value win' do
        speedups = described_class.new.file[described_class::SPEEDUPS_KEY]
        expect(speedups).to eq(default_speedups.merge('gsub_vs_tr' => false))
      end
    end

    context 'with project exclude paths' do
      before { create_file(described_class::FILE_NAME, ['exclude_paths:', "  - 'app/*.rb'"]) }

      it 'unions them with the shipped excludes rather than replacing them' do
        excludes = described_class.new.file[described_class::EXCLUDE_PATHS_KEY]
        expect(excludes).to eq(default_excludes + ['app/*.rb'])
      end
    end

    context 'with a new_speedups mode in the project file' do
      before { create_file(described_class::FILE_NAME, ['new_speedups: enable']) }

      it 'lets the project value win' do
        expect(described_class.new.file['new_speedups']).to eq('enable')
      end
    end
  end

  describe '#file_location' do
    it 'returns a file that is in the current dir (eg the project root)' do
      expect(described_class.new.file_location).to eq(expected_location)
    end

    it 'returns a file in an ancestor dir' do
      Dir.chdir("#{root}/spec/lib") do
        expect(described_class.new.file_location).to eq(expected_location)
      end
    end

    it 'returns nil when there is no ancestor file' do
      Dir.mktmpdir do |dir|
        Dir.chdir(dir) { expect(described_class.new.file_location).to be_nil }
      end
    end
  end

  describe '#default_config' do
    it 'is deep frozen, so a merged copy cannot mutate it' do
      expect(described_class.new.default_config[described_class::SPEEDUPS_KEY]).to be_frozen
    end
  end

  private

  def default_speedups
    Fastererer::DefaultConfig.load[described_class::SPEEDUPS_KEY]
  end

  def default_excludes
    Fastererer::DefaultConfig.load[described_class::EXCLUDE_PATHS_KEY]
  end
end
