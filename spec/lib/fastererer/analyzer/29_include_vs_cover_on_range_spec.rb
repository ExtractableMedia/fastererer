# frozen_string_literal: true

require 'spec_helper'

describe Fastererer::Analyzer do
  let(:test_file_path) { RSpec.root.join('support', 'analyzer', '29_include_vs_cover_on_range.rb') }

  it 'detects 3 include? method calls' do
    analyzer = described_class.new(test_file_path)
    analyzer.scan
    expect(analyzer.errors[:include_vs_cover_on_range].count).to eq(3)
  end
end
