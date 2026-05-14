# frozen_string_literal: true

require 'spec_helper'

describe Fastererer::Analyzer do
  let(:test_file_path) { RSpec.root.join('support', 'analyzer', '09_each_with_index_vs_while.rb') }

  it 'detects a for loop' do
    analyzer = described_class.new(test_file_path)
    analyzer.scan
    expect(analyzer.errors[:each_with_index_vs_while].count).to eq(1)
  end
end
