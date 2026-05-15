# frozen_string_literal: true

require 'spec_helper'

describe Fastererer::FileTraverser do
  include FileHelper

  include_context 'isolated environment'

  describe 'config_file' do
    context 'with no config file' do
      let(:file_traverser) { described_class.new('.') }

      it 'returns nil_config_file' do
        expect(file_traverser.config_file).to eq(file_traverser.send(:nil_config_file))
      end
    end

    context 'with empty config file' do
      before { create_file(Fastererer::FileTraverser::CONFIG_FILE_NAME, '') }

      let(:file_traverser) { described_class.new('.') }

      it 'returns nil_config_file' do
        expect(file_traverser.config_file).to eq(file_traverser.send(:nil_config_file))
      end
    end

    context 'with missing exclude_paths key' do
      before { create_file(Fastererer::FileTraverser::CONFIG_FILE_NAME, ['speedups:']) }

      let(:file_traverser) { described_class.new('.') }

      it 'returns nil_config_file' do
        expect(file_traverser.config_file).to eq(file_traverser.send(:nil_config_file))
      end
    end

    context 'with speedups content but no exclude_paths' do
      let(:config_file_content) do
        "speedups:\n  " \
          'keys_each_vs_each_key: true'
      end
      let(:file_traverser) { described_class.new('.') }

      before { create_file(Fastererer::FileTraverser::CONFIG_FILE_NAME, config_file_content) }

      it 'returns config_file with added exclude paths key' do
        expect(file_traverser.config_file)
          .to eq('speedups' => { 'keys_each_vs_each_key' => true }, 'exclude_paths' => [])
      end
    end

    context 'with exclude_paths content but no speedups' do
      let(:config_file_content) do
        "exclude_paths:\n  " \
          "- 'spec/support/analyzer/*.rb'"
      end
      let(:file_traverser) { described_class.new('.') }

      before { create_file(Fastererer::FileTraverser::CONFIG_FILE_NAME, config_file_content) }

      it 'returns config_file with added speedups key' do
        expect(file_traverser.config_file)
          .to eq('speedups' => {}, 'exclude_paths' => ['spec/support/analyzer/*.rb'])
      end
    end

    context 'with exclude_paths and speedups content' do
      let(:config_file_content) do
        "speedups:\n  " \
          "keys_each_vs_each_key: true\n" \
          "exclude_paths:\n  " \
          "- 'spec/support/analyzer/*.rb'"
      end
      let(:file_traverser) { described_class.new('.') }

      before { create_file(Fastererer::FileTraverser::CONFIG_FILE_NAME, config_file_content) }

      it 'returns config_file' do
        expect(file_traverser.config_file)
          .to eq('speedups' => { 'keys_each_vs_each_key' => true },
                 'exclude_paths' => ['spec/support/analyzer/*.rb'])
      end
    end

    context 'with empty values' do
      before do
        create_file(Fastererer::FileTraverser::CONFIG_FILE_NAME,
                    ['speedups:', '', 'exclude_paths:'])
      end

      let(:file_traverser) { described_class.new('.') }

      it 'returns nil_config_file' do
        expect(file_traverser.config_file).to eq(file_traverser.send(:nil_config_file))
      end
    end
  end

  describe 'scannable files' do
    let(:file_traverser) { described_class.new(argument) }

    context 'with no ARGV' do
      let(:argument) { '.' }

      # rubocop:disable RSpec/NestedGroups
      context 'when no files in folder' do
        it 'returns empty array' do
          expect(file_traverser.scannable_files).to eq([])
        end
      end

      context 'with only a non-ruby file inside' do
        before { create_file('something.yml') }

        it 'returns empty array' do
          expect(file_traverser.scannable_files).to eq([])
        end
      end

      context 'with a ruby file inside' do
        let(:file_name) { 'something.rb' }

        before { create_file(file_name) }

        it 'returns array with that file inside' do
          expect(file_traverser.scannable_files).to eq([file_name])
        end
      end

      context 'with a ruby file inside that is ignored' do
        let(:file_name) { 'something.rb' }

        let(:config_file_content) do
          "exclude_paths:\n  " \
            "- '#{file_name}'"
        end

        before do
          create_file(Fastererer::FileTraverser::CONFIG_FILE_NAME, config_file_content)
          create_file(file_name)
        end

        it 'returns empty array' do
          expect(file_traverser.scannable_files).to eq([])
        end
      end

      context 'with a ruby file inside that is not ignored' do
        let(:file_name) { 'something.rb' }

        let(:config_file_content) do
          "exclude_paths:\n  " \
            "- 'sumthing.rb'"
        end

        before do
          create_file(Fastererer::FileTraverser::CONFIG_FILE_NAME, config_file_content)
          create_file(file_name)
        end

        it 'returns empty array' do
          expect(file_traverser.scannable_files).to eq([file_name])
        end
      end

      context 'with nested ruby files' do
        before do
          create_file('something.rb')
          create_file('nested/something.rb')
        end

        it 'returns files properly' do
          expect(file_traverser.scannable_files)
            .to contain_exactly('something.rb', 'nested/something.rb')
        end
      end

      context 'with nested ruby files explicitly ignored' do
        let(:config_file_content) do
          "exclude_paths:\n  " \
            "- 'nested/something.rb'"
        end

        before do
          create_file(Fastererer::FileTraverser::CONFIG_FILE_NAME, config_file_content)
          create_file('something.rb')
          create_file('nested/something.rb')
        end

        it 'returns unignored files' do
          expect(file_traverser.scannable_files).to contain_exactly('something.rb')
        end
      end

      context 'with nested ruby files ignored via *' do
        let(:config_file_content) do
          "exclude_paths:\n  " \
            "- 'nested/*'"
        end

        before do
          create_file(Fastererer::FileTraverser::CONFIG_FILE_NAME, config_file_content)
          create_file('something.rb')
          create_file('nested/something.rb')
        end

        it 'returns unignored files' do
          expect(file_traverser.scannable_files).to contain_exactly('something.rb')
        end
      end

      context 'with unnested ruby files ignored' do
        let(:config_file_content) do
          "exclude_paths:\n  " \
            "- 'something.rb'"
        end

        before do
          create_file(Fastererer::FileTraverser::CONFIG_FILE_NAME, config_file_content)
          create_file('something.rb')
          create_file('nested/something.rb')
        end

        it 'returns unignored files' do
          expect(file_traverser.scannable_files).to contain_exactly('nested/something.rb')
        end
      end
      # rubocop:enable RSpec/NestedGroups
    end

    context 'with one file argument' do
      let(:argument) { 'something.rb' }

      # rubocop:disable RSpec/NestedGroups
      context 'without a config file' do
        before { create_file('something.rb') }

        it 'returns that file' do
          expect(file_traverser.scannable_files).to contain_exactly(argument)
        end
      end

      context 'with a config file ignoring it' do
        let(:config_file_content) do
          "exclude_paths:\n  " \
            "- 'something.rb'"
        end

        before do
          create_file(Fastererer::FileTraverser::CONFIG_FILE_NAME, config_file_content)
          create_file('something.rb')
        end

        it 'returns empty array' do
          expect(file_traverser.scannable_files).to be_empty
        end
      end
      # rubocop:enable RSpec/NestedGroups
    end

    context 'with one folder argument' do
      let(:argument) { 'nested/' }

      let(:file_names) { ['nested/something.rb', 'nested/something_else.rb'] }

      # rubocop:disable RSpec/NestedGroups
      context 'without a config file' do
        before { file_names.each { |file_name| create_file(file_name) } }

        it 'returns those files' do
          expect(file_traverser.scannable_files).to match_array(file_names)
        end
      end

      context 'with a config file ignoring it' do
        let(:config_file_content) do
          "exclude_paths:\n  " \
            "- 'nested/*'"
        end

        before do
          create_file(Fastererer::FileTraverser::CONFIG_FILE_NAME, config_file_content)
          file_names.each { |file_name| create_file(file_name) }
        end

        it 'returns empty array' do
          expect(file_traverser.scannable_files).to be_empty
        end
      end
      # rubocop:enable RSpec/NestedGroups
    end
  end

  describe 'non-existent path' do
    let(:file_traverser) { described_class.new('no_such_path') }

    it 'outputs an error message' do
      allow(file_traverser).to receive(:puts)
      file_traverser.traverse
      expect(file_traverser).to have_received(:puts)
        .with(a_string_matching(/No such file or directory/))
    end
  end

  describe 'parse errors' do
    before do
      create_file('user.rb', '[]*/sa*()')
      file_traverser.traverse
    end

    let(:file_traverser) { described_class.new('.') }

    it 'has errors' do
      expect(file_traverser.parse_error_paths.first)
        .to start_with('user.rb - RubyParser::SyntaxError - unterminated')
    end
  end

  describe 'output' do
    let(:test_file_path) { RSpec.root.join('support', 'output', 'sample_code.rb') }
    let(:analyzer) { Fastererer::Analyzer.new(test_file_path) }
    let(:file_traverser) { described_class.new('.') }

    before { analyzer.scan }

    context 'when the analyzer has offenses' do
      let(:explanation) { Fastererer::Explanation.new(:for_loop_vs_each) }

      it 'prints offense' do
        expect { file_traverser.send(:output, analyzer) }
          .to output(include("#{test_file_path}:1", explanation.to_s)).to_stdout
      end
    end
  end
end
