# frozen_string_literal: true

require 'spec_helper'

describe Fastererer::Analyzer do
  let(:test_file_path) do
    RSpec.root.join('support', 'analyzer', '16_hash_merge_bang_vs_hash_brackets.rb')
  end

  it 'detects keys each 3 times' do
    analyzer = described_class.new(test_file_path)
    analyzer.scan
    expect(analyzer.errors[:hash_merge_bang_vs_hash_brackets].count).to eq(3)
  end
end
