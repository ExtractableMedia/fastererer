# frozen_string_literal: true

require 'spec_helper'

describe Fastererer::Analyzer do
  let(:test_file_path) { RSpec.root.join('support', 'analyzer', '12_select_first_vs_detect.rb') }

  it 'detects sort once' do
    analyzer = described_class.new(test_file_path)
    analyzer.scan
    expect(analyzer.errors[:select_first_vs_detect].count).to eq(3)
  end
end
