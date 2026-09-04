# frozen_string_literal: true

require 'spec_helper'

describe Fastererer::MethodCallScanner do
  include ParserHelpers

  subject(:scanner) { described_class.new(call_element) }

  def second_statement(code)
    Fastererer::Parser.parse(code).statements.body[1]
  end

  context 'when the receiver is a method call named like a chained method' do
    let(:call_element) { parse_first_statement('arr.shuffle.first') }

    it 'flags shuffle.first as an offense', :aggregate_failures do
      expect(scanner).to be_offense_detected
      expect(scanner.offense.name).to eq(:shuffle_first_vs_sample)
    end
  end

  # call_name, not a duck-typed name match, is what keeps these from reading as chained calls
  context 'when the receiver is a variable named like a chained method' do
    [
      ['shuffle = []', 'shuffle.first'],
      ['reverse = []', 'reverse.each { |element| element }'],
      ['keys = []', 'keys.each { |element| element }'],
      ['map = []', 'map.flatten(1)'],
      ['select = []', 'select.last']
    ].each do |assignment, call|
      context "with #{call}" do
        let(:call_element) { second_statement("#{assignment}\n#{call}") }

        it 'does not flag a false offense' do
          expect(scanner).not_to be_offense_detected
        end
      end
    end
  end

  context 'when the call has an implicit receiver' do
    ['first', 'each { |element| element }', 'flatten(1)', 'last', 'include?(2)'].each do |call|
      context "with #{call}" do
        let(:call_element) { parse_first_statement(call) }

        it 'does not flag a false offense' do
          expect(scanner).not_to be_offense_detected
        end
      end
    end
  end
end
