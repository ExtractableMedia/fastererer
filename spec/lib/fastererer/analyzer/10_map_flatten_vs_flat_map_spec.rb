# frozen_string_literal: true

require 'spec_helper'

describe Fastererer::Analyzer do
  let(:test_file_path) { RSpec.root.join('support', 'analyzer', '10_map_flatten_vs_flat_map.rb') }

  it 'detects a map{}.flatten(1)' do
    analyzer = described_class.new(test_file_path)
    analyzer.scan
    expect(analyzer.errors[:map_flatten_vs_flat_map].count).to eq(2)
  end
end
