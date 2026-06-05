# frozen_string_literal: true

require 'spec_helper'

describe Fastererer::Analyzer do
  subject(:analyzer) { described_class.new(test_file_path) }

  let(:test_file_path) { RSpec.root.join('support', 'analyzer', '18_block_vs_symbol_to_proc.rb') }

  before { analyzer.scan }

  it 'flags only the lines reducible to symbol-to-proc' do
    offending_lines = analyzer.errors[:block_vs_symbol_to_proc].map(&:line)
    expect(offending_lines).to contain_exactly(5, 34, 37, 38, 39, 40, 43, 45, 46, 49)
  end

  it 'does not flag a safe-navigation block body' do
    flagged = analyzer.errors[:block_vs_symbol_to_proc].map(&:line)
    expect(flagged).not_to include(51) # numbers.map { |number| number&.to_s }
  end
end
