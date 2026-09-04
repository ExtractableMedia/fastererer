# frozen_string_literal: true

require 'spec_helper'

describe Fastererer::Analyzer do
  subject(:analyzer) { described_class.new(test_file_path) }

  let(:test_file_path) { RSpec.root.join('support', 'analyzer', '18_block_vs_symbol_to_proc.rb') }
  let(:flagged_lines) { analyzer.errors[:block_vs_symbol_to_proc].map(&:line) }

  before { analyzer.scan }

  it 'flags only the lines reducible to symbol-to-proc' do
    expect(flagged_lines).to contain_exactly(5, 34, 37, 38, 39, 40, 43, 45, 46, 49)
  end

  it 'does not flag a primitive-receiver block body' do
    expect(flagged_lines).not_to include(14) # the each block whose body is [].finalize!
  end

  it 'does not flag a safe-navigation block body' do
    expect(flagged_lines).not_to include(51) # numbers.map { |number| number&.to_s }
  end

  it 'does not flag a block whose only named param is not the first' do
    expect(flagged_lines).not_to include(53) # |(name, routes), index|
  end

  it 'does not flag a block with a destructured trailing param' do
    expect(flagged_lines).not_to include(54) # |name, (routes, index)|
  end
end
