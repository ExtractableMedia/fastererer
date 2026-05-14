# frozen_string_literal: true

require 'spec_helper'

describe Fastererer::Analyzer do
  let(:test_file_path) do
    RSpec.root.join('support', 'analyzer', '25_select_last_vs_reverse_detect.rb')
  end

  it 'detects select last once' do
    analyzer = described_class.new(test_file_path)
    analyzer.scan
    expect(analyzer.errors[:select_last_vs_reverse_detect].count).to eq(1)
  end
end
