# frozen_string_literal: true

require 'spec_helper'

describe Fastererer::Formatters do
  describe '.fetch' do
    it 'returns the text formatter class' do
      expect(described_class.fetch('text')).to eq(Fastererer::Formatters::TextFormatter)
    end

    it 'returns the json formatter class' do
      expect(described_class.fetch('json')).to eq(Fastererer::Formatters::JsonFormatter)
    end

    it 'returns the rdjsonl formatter class' do
      expect(described_class.fetch('rdjsonl')).to eq(Fastererer::Formatters::RdjsonlFormatter)
    end

    context 'with an unknown format' do
      it 'raises with the valid formats listed' do
        expect { described_class.fetch('bogus') }
          .to raise_error(Fastererer::UnknownFormatError, /Valid formats: text, json, rdjsonl/)
      end
    end
  end
end
