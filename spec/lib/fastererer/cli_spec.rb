# frozen_string_literal: true

require 'spec_helper'

# This spec exercises the executable as a black box (shells out to
# `exe/fastererer` and asserts on exit codes), so its subject is the
# CLI binary, not a Ruby class.
# rubocop:disable RSpec/DescribeClass
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
  end

  describe 'color output' do
    # Backtick subshells are non-TTY, so these only assert the negative; positive in painter_spec.
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

  def fasterer_bin
    File.expand_path('../../../exe/fastererer', __dir__)
  end
end
# rubocop:enable RSpec/DescribeClass
