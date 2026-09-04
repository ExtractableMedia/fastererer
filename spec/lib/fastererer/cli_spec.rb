# frozen_string_literal: true

require 'spec_helper'
require 'json'

describe Fastererer::CLI do
  include FileHelper

  include_context 'isolated environment'

  describe '.execute' do
    before { stub_const('ARGV', argv) }

    let(:argv) { [] }
    let(:config_name) { Fastererer::Config::FILE_NAME }

    context 'when a scanned file has an offense' do
      before { create_file('user.rb', '[].shuffle.first') }

      it 'exits 1 so the shell sees a failing status', :aggregate_failures do
        expect { described_class.execute }
          .to raise_error(SystemExit) { |error| expect(error.status).to eq(1) }
      end
    end

    context 'when no scanned file has an offense' do
      before { create_file('user.rb', '[].sample') }

      it 'returns without aborting' do
        expect { described_class.execute }.not_to raise_error
      end
    end

    context 'when the given path does not exist' do
      let(:argv) { ['no_such_path'] }

      it 'warns on stderr and exits 2 to distinguish a usage error', :aggregate_failures do
        expect { described_class.execute }
          .to output(/No such file or directory/).to_stderr
          .and raise_error(SystemExit) { |error| expect(error.status).to eq(2) }
      end
    end

    context 'when given an unknown flag' do
      let(:argv) { ['--nope'] }

      it 'warns on stderr and exits 2 rather than dumping a backtrace', :aggregate_failures do
        expect { described_class.execute }
          .to output(/invalid option: --nope/).to_stderr
          .and raise_error(SystemExit) { |error| expect(error.status).to eq(2) }
      end
    end

    context 'with a path argument' do
      let(:argv) { ['nested'] }

      before { create_file('nested/user.rb', '[].sample') }

      it 'scans the path it was given' do
        allow(Fastererer::FileTraverser).to receive(:new).and_call_original
        described_class.execute
        expect(Fastererer::FileTraverser).to have_received(:new).with('nested', formatter: anything)
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

    context 'with --format text named explicitly' do
      let(:argv) { ['--format=text'] }
      let(:out) { StringIO.new }

      before do
        Fastererer::Painter.disable!
        create_file('user.rb', '[].shuffle.first')
      end

      after { Fastererer::Painter.enable! }

      it 'renders the human-readable report', :aggregate_failures do
        expect { described_class.execute(out: out) }.to raise_error(SystemExit)
        expect(out.string).to include('user.rb:1: W: Performance/ShuffleFirstVsSample')
      end
    end

    context 'with --format json' do
      let(:argv) { ['--format', 'json'] }
      let(:out) { StringIO.new }

      before { create_file('user.rb', '[].shuffle.first') }

      it 'writes the real scan to the injected stream', :aggregate_failures do
        expect { described_class.execute(out: out) }.to raise_error(SystemExit)
        expect(JSON.parse(out.string)['offenses'])
          .to contain_exactly(hash_including('path' => 'user.rb', 'line' => 1,
                                             'rule' => 'Performance/ShuffleFirstVsSample'))
      end
    end

    context 'with an unknown format' do
      let(:argv) { ['--format', 'bogus'] }
      let(:err) { StringIO.new }

      it 'names the format on the error stream and exits', :aggregate_failures do
        expect { described_class.execute(err: err) }.to raise_error(SystemExit)
        expect(err.string).to include('Unknown format')
      end
    end

    context 'with a speedup held back by the default warn mode' do
      let(:err) { StringIO.new }
      let(:out) { StringIO.new }

      before { create_file(config_name, ['speedups:', '  gsub_vs_tr: pending']) }

      it 'names it on the error stream' do
        described_class.execute(out: out, err: err)
        expect(err.string).to include('1 new speedup is held back: gsub_vs_tr')
      end

      it 'points at both ways to resolve it' do
        described_class.execute(out: out, err: err)
        expect(err.string).to include('Set new_speedups to `enable`')
      end

      it 'keeps the notice off the output stream' do
        described_class.execute(out: out, err: err)
        expect(out.string).not_to include('held back')
      end
    end

    context 'with several speedups held back' do
      let(:err) { StringIO.new }

      before do
        create_file(config_name,
                    ['speedups:', '  gsub_vs_tr: pending', '  sort_vs_sort_by: pending'])
      end

      it 'pluralizes the notice' do
        described_class.execute(out: StringIO.new, err: err)
        expect(err.string).to include('2 new speedups are held back')
      end
    end

    context 'with a held-back speedup and new_speedups set to enable' do
      let(:err) { StringIO.new }

      before do
        create_file(config_name, ['speedups:', '  gsub_vs_tr: pending', 'new_speedups: enable'])
      end

      it 'says nothing, because nothing is being held back' do
        described_class.execute(out: StringIO.new, err: err)
        expect(err.string).to be_empty
      end
    end

    context 'with a held-back speedup and new_speedups set to disable' do
      let(:err) { StringIO.new }

      before do
        create_file(config_name, ['speedups:', '  gsub_vs_tr: pending', 'new_speedups: disable'])
      end

      it 'says nothing, because the user already decided' do
        described_class.execute(out: StringIO.new, err: err)
        expect(err.string).to be_empty
      end
    end

    context 'with an unreadable configuration' do
      let(:err) { StringIO.new }

      before { create_file(config_name, ['new_speedups: sometimes']) }

      it 'reports the problem and exits with the usage status', :aggregate_failures do
        expect { described_class.execute(err: err) }
          .to raise_error(SystemExit) { |error| expect(error.status).to eq(2) }
        expect(err.string).to include('new_speedups must be one of')
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

    it 'records --format' do
      expect(described_class.parse_options(['--format', 'json'])).to include(format: 'json')
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
