# frozen_string_literal: true

require 'spec_helper'
require 'open3'
require 'json'

# This spec exercises the executable as a black box (shells out to `exe/fastererer` and asserts on
# exit codes), so its subject is the CLI binary, not a Ruby class
# rubocop:disable-next RSpec/DescribeClass
describe 'Fastererer CLI' do
  include FileHelper

  include_context 'isolated environment'

  describe 'exit status' do
    context 'when there are no scannable files' do
      it 'exits 0' do
        `#{fasterer_bin}`
        expect($CHILD_STATUS.exitstatus).to eq(0)
      end
    end

    context 'when scanned files have no offenses' do
      it 'exits 0' do
        create_file('user.rb', '[].sample')
        `#{fasterer_bin}`
        expect($CHILD_STATUS.exitstatus).to eq(0)
      end
    end

    context 'when a scanned file has offenses' do
      it 'exits 1' do
        create_file('user.rb', '[].shuffle.first')
        `#{fasterer_bin}`
        expect($CHILD_STATUS.exitstatus).to eq(1)
      end
    end

    context 'when the given path does not exist' do
      it 'exits 2' do
        `#{fasterer_bin} no_such_path 2>/dev/null`
        expect($CHILD_STATUS.exitstatus).to eq(2)
      end
    end

    context 'when given an unknown flag' do
      it 'exits 2' do
        `#{fasterer_bin} --nope 2>/dev/null`
        expect($CHILD_STATUS.exitstatus).to eq(2)
      end
    end
  end

  describe 'stream routing' do
    before { create_file('bad.rb', '[]*/sa*()') }

    it 'keeps parse-error diagnostics off stdout' do
      expect(`#{fasterer_bin} 2>/dev/null`).not_to include('Unprocessable files were')
    end

    it 'keeps the statistics line on stdout' do
      expect(`#{fasterer_bin} 2>/dev/null`).to include('1 unparsable file found')
    end
  end

  describe 'color output' do
    # Backtick subshells are non-TTY, so these only assert the negative; positive in painter_spec
    before { create_file('user.rb', '[].shuffle.first') }

    it 'auto-disables color when STDOUT is piped' do
      output = `#{fasterer_bin}`
      aggregate_failures do
        expect(output).not_to include("\e[")
        expect(output).to include('user.rb')
      end
    end

    it 'auto-disables color when NO_COLOR is set' do
      output = `NO_COLOR=1 #{fasterer_bin}`
      expect(output).not_to include("\e[")
    end

    it 'auto-disables color when --no-color is passed' do
      output = `#{fasterer_bin} --no-color`
      expect(output).not_to include("\e[")
    end
  end

  describe 'format option' do
    before { create_file('user.rb', '[].shuffle.first') }

    it 'emits valid JSON on stdout with --format=json', :aggregate_failures do
      stdout, _stderr, status = Open3.capture3(fasterer_bin, '--format', 'json')
      expect(JSON.parse(stdout)['offenses'])
        .to contain_exactly(include('line' => 1, 'rule' => 'Performance/ShuffleFirstVsSample'))
      expect(status.exitstatus).to eq(1)
    end

    it 'emits a reviewdog record naming the configuration key with -f rdjsonl' do
      stdout, = Open3.capture3(fasterer_bin, '-f', 'rdjsonl')
      diagnostic = JSON.parse(stdout.lines.first.to_s)

      expect(diagnostic).to include('severity' => 'WARNING',
                                    'code' => include('value' => 'shuffle_first_vs_sample'))
    end

    it 'emits a workflow command naming the configuration key with -f github' do
      stdout, = Open3.capture3(fasterer_bin, '-f', 'github')

      expect(stdout).to start_with('::warning file=user.rb,line=1::shuffle_first_vs_sample: ')
    end

    it 'reports an unknown format on stderr and exits non-zero', :aggregate_failures do
      stdout, stderr, status = Open3.capture3(fasterer_bin, '--format', 'bogus')
      expect(stdout).to be_empty
      expect(stderr).to include('Unknown format')
      expect(status.exitstatus).to eq(2)
    end
  end

  private

  def fasterer_bin
    File.expand_path('../../exe/fastererer', __dir__)
  end
end
