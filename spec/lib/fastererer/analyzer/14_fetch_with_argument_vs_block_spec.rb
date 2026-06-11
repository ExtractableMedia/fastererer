# frozen_string_literal: true

require 'spec_helper'

describe Fastererer::Analyzer do
  subject(:analyzer) { described_class.new(test_file_path) }

  let(:test_file_path) do
    RSpec.root.join('support', 'analyzer', '14_fetch_with_argument_vs_block.rb')
  end

  before { analyzer.scan }

  it 'detects fetch with argument once' do
    expect(analyzer.errors[:fetch_with_argument_vs_block].count).to eq(1)
  end
end
