# frozen_string_literal: true

require 'spec_helper'

describe Fastererer::Analyzer do
  let(:test_file_path) { RSpec.root.join('support', 'analyzer', '18_block_vs_symbol_to_proc.rb') }

  it 'blocks that could be called with symbol 9 times' do
    analyzer = described_class.new(test_file_path)
    analyzer.scan
    expect(analyzer.errors[:block_vs_symbol_to_proc].count).to eq(9)
  end
end
