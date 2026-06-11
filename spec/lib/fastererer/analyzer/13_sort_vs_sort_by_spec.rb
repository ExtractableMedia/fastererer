# frozen_string_literal: true

require 'spec_helper'

describe Fastererer::Analyzer do
  subject(:analyzer) { described_class.new(test_file_path) }

  let(:test_file_path) { RSpec.root.join('support', 'analyzer', '13_sort_vs_sort_by.rb') }

  before { analyzer.scan }

  it 'detects sort once' do
    expect(analyzer.errors[:sort_vs_sort_by].count).to eq(1)
  end
end
