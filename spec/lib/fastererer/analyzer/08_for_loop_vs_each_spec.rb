# frozen_string_literal: true

require 'spec_helper'

describe Fastererer::Analyzer do
  let(:test_file_path) { RSpec.root.join('support', 'analyzer', '08_for_loop_vs_each.rb') }

  it 'detects a for loop' do
    analyzer = described_class.new(test_file_path)
    analyzer.scan
    expect(analyzer.errors[:for_loop_vs_each].count).to eq(1)
  end
end
