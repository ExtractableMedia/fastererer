# frozen_string_literal: true

require 'spec_helper'

describe Fastererer::Analyzer do
  let(:test_file_path) { RSpec.root.join('support', 'analyzer', '03_module_eval.rb') }

  it 'detects module eval' do
    analyzer = described_class.new(test_file_path)
    analyzer.scan
    expect(analyzer.errors[:module_eval].count).to eq(1)
  end
end
