# frozen_string_literal: true

require 'spec_helper'

describe Fastererer::Analyzer do
  let(:test_file_path) do
    RSpec.root.join('support', 'analyzer', '11_reverse_each_vs_reverse_each.rb')
  end

  it 'detects a for loop' do
    analyzer = described_class.new(test_file_path)
    analyzer.scan
    expect(analyzer.errors[:reverse_each_vs_reverse_each].count).to eq(2)
  end
end
