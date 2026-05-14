# frozen_string_literal: true

require 'spec_helper'

describe Fastererer::Analyzer do
  let(:test_file_path) { RSpec.root.join('support', 'analyzer', '13_sort_vs_sort_by.rb') }

  it 'detects sort once' do
    analyzer = described_class.new(test_file_path)
    analyzer.scan
    expect(analyzer.errors[:sort_vs_sort_by].count).to eq(1)
  end
end
