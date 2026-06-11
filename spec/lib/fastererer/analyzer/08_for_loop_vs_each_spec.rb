# frozen_string_literal: true

require 'spec_helper'

describe Fastererer::Analyzer do
  subject(:analyzer) { described_class.new(test_file_path) }

  let(:test_file_path) { RSpec.root.join('support', 'analyzer', '08_for_loop_vs_each.rb') }

  before { analyzer.scan }

  it 'detects every for loop at its line number' do
    expect(analyzer.errors[:for_loop_vs_each].map(&:line)).to eq([1, 5])
  end

  it 'descends into the loop body to detect nested offenses' do
    expect(analyzer.errors[:shuffle_first_vs_sample].count).to eq(1)
  end
end
