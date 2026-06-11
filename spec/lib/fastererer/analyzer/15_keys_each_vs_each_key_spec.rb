# frozen_string_literal: true

require 'spec_helper'

describe Fastererer::Analyzer do
  subject(:analyzer) { described_class.new(test_file_path) }

  let(:test_file_path) { RSpec.root.join('support', 'analyzer', '15_keys_each_vs_each_key.rb') }

  before { analyzer.scan }

  it 'detects keys each 3 times' do
    expect(analyzer.errors[:keys_each_vs_each_key].count).to eq(3)
  end
end
