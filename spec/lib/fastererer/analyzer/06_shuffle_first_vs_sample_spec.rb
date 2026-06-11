# frozen_string_literal: true

require 'spec_helper'

describe Fastererer::Analyzer do
  subject(:analyzer) { described_class.new(test_file_path) }

  let(:test_file_path) { RSpec.root.join('support', 'analyzer', '06_shuffle_first_vs_sample.rb') }

  before { analyzer.scan }

  it 'detects shuffle.first 5 times' do
    expect(analyzer.errors[:shuffle_first_vs_sample].count).to eq(5)
  end
end
