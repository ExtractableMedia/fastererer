# frozen_string_literal: true

require 'spec_helper'
require 'pathname'
require 'tmpdir'

describe Fastererer::Config do
  let(:root) { Pathname.new("#{File.dirname(__FILE__)}/../../..").cleanpath }
  let(:expected_location) { "#{root}/.fastererer.yml" }

  describe '#ignored_speedups' do
    include FileHelper

    include_context 'isolated environment'

    it 'returns the speedups the config switches off' do
      create_file(described_class::FILE_NAME, ['speedups:', '  gsub_vs_tr: false'])
      expect(described_class.new.ignored_speedups).to eq([:gsub_vs_tr])
    end

    it 'omits the speedups the config leaves on' do
      create_file(described_class::FILE_NAME, ['speedups:', '  gsub_vs_tr: true'])
      expect(described_class.new.ignored_speedups).to be_empty
    end

    it 'ignores nothing when there is no config file' do
      expect(described_class.new.ignored_speedups).to be_empty
    end
  end

  describe '#file' do
    let(:nil_file) { { 'speedups' => {}, 'exclude_paths' => [] } }

    context 'without an ancestor file' do
      around { |example| Dir.mktmpdir { |dir| Dir.chdir(dir) { example.run } } }

      it 'returns the nil_file fallback' do
        expect(described_class.new.file).to eq(nil_file)
      end

      it 'memoizes the result across calls' do
        config = described_class.new
        expect(config.file).to equal(config.file)
      end
    end

    it 'calls YAML.load_file at most once when a config exists' do
      config = described_class.new
      allow(YAML).to receive(:load_file).and_call_original
      2.times { config.file }
      expect(YAML).to have_received(:load_file).once
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
end
