# frozen_string_literal: true

require 'spec_helper'

describe Fastererer::Painter do
  include EnvHelper

  before { described_class.enable! }
  after { described_class.enable! }

  describe '.paint' do
    let(:red_wrapped) { "\e[31mhello\e[0m" }

    context 'when STDOUT is a TTY and color is enabled' do
      before { allow($stdout).to receive(:tty?).and_return(true) }

      around { |example| with_env('NO_COLOR', nil) { example.run } }

      it 'wraps the string in ANSI codes' do
        expect(described_class.paint('hello', :red)).to eq(red_wrapped)
      end
    end

    context 'when NO_COLOR is set to a non-empty value' do
      before { allow($stdout).to receive(:tty?).and_return(true) }

      around { |example| with_env('NO_COLOR', '1') { example.run } }

      it 'returns the bare string' do
        expect(described_class.paint('hello', :red)).to eq('hello')
      end
    end

    context 'when NO_COLOR is set to an empty value' do
      before { allow($stdout).to receive(:tty?).and_return(true) }

      around { |example| with_env('NO_COLOR', '') { example.run } }

      it 'still wraps the string in ANSI codes' do
        expect(described_class.paint('hello', :red)).to eq(red_wrapped)
      end
    end

    context 'when Painter has been disabled' do
      before do
        allow($stdout).to receive(:tty?).and_return(true)
        described_class.disable!
      end

      around { |example| with_env('NO_COLOR', nil) { example.run } }

      it 'returns the bare string' do
        expect(described_class.paint('hello', :red)).to eq('hello')
      end
    end

    context 'when Painter has been disabled then re-enabled' do
      before do
        allow($stdout).to receive(:tty?).and_return(true)
        described_class.disable!
        described_class.enable!
      end

      around { |example| with_env('NO_COLOR', nil) { example.run } }

      it 'wraps the string in ANSI codes' do
        expect(described_class.paint('hello', :red)).to eq(red_wrapped)
      end
    end

    context 'when Painter is disabled and NO_COLOR is empty' do
      before do
        allow($stdout).to receive(:tty?).and_return(true)
        described_class.disable!
      end

      around { |example| with_env('NO_COLOR', '') { example.run } }

      it 'returns the bare string' do
        expect(described_class.paint('hello', :red)).to eq('hello')
      end
    end

    context 'when STDOUT is not a TTY' do
      before { allow($stdout).to receive(:tty?).and_return(false) }

      around { |example| with_env('NO_COLOR', nil) { example.run } }

      it 'returns the bare string' do
        expect(described_class.paint('hello', :red)).to eq('hello')
      end
    end

    context 'with an unsupported color' do
      it 'raises ArgumentError' do
        expect { described_class.paint('hello', :purple) }.to raise_error(ArgumentError)
      end
    end

    describe 'color code mapping' do
      let(:ansi_codes) { { red: "\e[31mx\e[0m", green: "\e[32mx\e[0m", magenta: "\e[35mx\e[0m" } }

      before { allow($stdout).to receive(:tty?).and_return(true) }

      around { |example| with_env('NO_COLOR', nil) { example.run } }

      it 'wraps each color in the correct ANSI code', :aggregate_failures do
        ansi_codes.each do |color, expected|
          expect(described_class.paint('x', color)).to eq(expected)
        end
      end
    end
  end
end
