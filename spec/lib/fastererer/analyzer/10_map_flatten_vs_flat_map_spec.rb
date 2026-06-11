# frozen_string_literal: true

require 'spec_helper'

describe Fastererer::Analyzer do
  subject(:analyzer) { described_class.new(test_file_path) }

  let(:test_file_path) { RSpec.root.join('support', 'analyzer', '10_map_flatten_vs_flat_map.rb') }

  before { analyzer.scan }

  it 'detects map.flatten twice' do
    expect(analyzer.errors[:map_flatten_vs_flat_map].count).to eq(2)
  end
end
