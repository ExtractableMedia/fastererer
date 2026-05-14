# frozen_string_literal: true

require 'spec_helper'

describe Fastererer::Analyzer do
  let(:test_file_path) { RSpec.root.join('support', 'analyzer', '26_getter_vs_attr_reader.rb') }

  it 'detects 2 getters' do
    analyzer = described_class.new(test_file_path)
    analyzer.scan
    expect(analyzer.errors[:getter_vs_attr_reader].count).to eq(2)
  end
end
