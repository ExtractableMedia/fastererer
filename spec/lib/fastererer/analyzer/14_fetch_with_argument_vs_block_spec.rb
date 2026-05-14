# frozen_string_literal: true

require 'spec_helper'

describe Fastererer::Analyzer do
  let(:test_file_path) do
    RSpec.root.join('support', 'analyzer', '14_fetch_with_argument_vs_block.rb')
  end

  it 'detects keys fetch with argument once' do
    analyzer = described_class.new(test_file_path)
    analyzer.scan
    expect(analyzer.errors[:fetch_with_argument_vs_block].count).to eq(1)
  end
end
