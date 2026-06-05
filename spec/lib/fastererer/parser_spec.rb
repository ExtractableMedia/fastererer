# frozen_string_literal: true

require 'spec_helper'

describe Fastererer::Parser do
  describe '.parse' do
    it 'returns the AST root for valid code' do
      expect(described_class.parse('foo.bar')).to be_a(Prism::ProgramNode)
    end

    it 'raises ParseError for invalid code' do
      expect { described_class.parse('def') }.to raise_error(Fastererer::ParseError)
    end

    it 'surfaces every parse error, not just the first' do
      expect { described_class.parse('}{') }
        .to raise_error(Fastererer::ParseError, /ignoring it.*ignoring it/m)
    end
  end
end
