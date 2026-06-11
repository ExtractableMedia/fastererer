# frozen_string_literal: true

require 'spec_helper'

describe Fastererer::Analyzer do
  subject(:analyzer) { described_class.new(test_file_path) }

  let(:test_file_path) { RSpec.root.join('support', 'analyzer', '24_gsub_vs_tr.rb') }

  before { analyzer.scan }

  it 'detects gsub twice' do
    expect(analyzer.errors[:gsub_vs_tr].count).to eq(2)
  end
end
