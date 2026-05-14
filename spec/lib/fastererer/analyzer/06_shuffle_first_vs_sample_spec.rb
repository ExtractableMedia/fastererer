# frozen_string_literal: true

require 'spec_helper'

describe Fastererer::Analyzer do
  let(:test_file_path) { RSpec.root.join('support', 'analyzer', '06_shuffle_first_vs_sample.rb') }

  it 'detects a for loop' do
    analyzer = described_class.new(test_file_path)
    analyzer.scan
    expect(analyzer.errors[:shuffle_first_vs_sample].count).to eq(5)
  end
end
