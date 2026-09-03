# frozen_string_literal: true

require 'spec_helper'

describe Fastererer::CLI do
  include FileHelper

  include_context 'isolated environment'

  describe '.execute' do
    before { stub_const('ARGV', argv) }

    let(:argv) { [] }

    context 'when a scanned file has an offense' do
      before { create_file('user.rb', '[].shuffle.first') }

      it 'aborts so the shell sees a failing status' do
        expect { described_class.execute }.to raise_error(SystemExit)
      end
    end

    context 'when no scanned file has an offense' do
      before { create_file('user.rb', '[].sample') }

      it 'returns without aborting' do
        expect { described_class.execute }.not_to raise_error
      end
    end

    context 'with a path argument' do
      let(:argv) { ['nested'] }

      before { create_file('nested/user.rb', '[].sample') }

      it 'scans the path it was given' do
        allow(Fastererer::FileTraverser).to receive(:new).and_call_original
        described_class.execute
        expect(Fastererer::FileTraverser).to have_received(:new).with('nested')
      end
    end

    context 'with --no-color' do
      let(:argv) { ['--no-color'] }

      before { allow(Fastererer::Painter).to receive(:disable!) }

      it 'disables the painter' do
        described_class.execute
        expect(Fastererer::Painter).to have_received(:disable!)
      end
    end

    context 'without --no-color' do
      before { allow(Fastererer::Painter).to receive(:disable!) }

      it 'leaves the painter to decide for itself' do
        described_class.execute
        expect(Fastererer::Painter).not_to have_received(:disable!)
      end
    end
  end

  describe '.parse_options' do
    it 'takes the first non-flag argument as the path' do
      expect(described_class.parse_options(['lib'])).to include(path: 'lib')
    end

    it 'leaves the path nil when only flags are given' do
      expect(described_class.parse_options(['--no-color'])[:path]).to be_nil
    end

    it 'records --no-color' do
      expect(described_class.parse_options(['--no-color'])).to include(no_color: true)
    end

    it 'rejects an unknown flag' do
      expect { described_class.parse_options(['--nope']) }
        .to raise_error(OptionParser::InvalidOption)
    end

    it 'prints the version and exits for --version' do
      expect { described_class.parse_options(['--version']) }
        .to output("#{Fastererer::VERSION}\n").to_stdout.and raise_error(SystemExit)
    end

    it 'prints the usage banner and exits for --help' do
      expect { described_class.parse_options(['--help']) }
        .to output(/Usage: fastererer/).to_stdout.and raise_error(SystemExit)
    end
  end
end
