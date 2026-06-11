# frozen_string_literal: true

require 'spec_helper'

describe Fastererer::Analyzer do
  subject(:analyzer) { described_class.new(test_file_path) }

  let(:test_file_path) do
    RSpec.root.join('support', 'analyzer', '11_reverse_each_vs_reverse_each.rb')
  end

  before { analyzer.scan }

  it 'detects reverse.each twice' do
    expect(analyzer.errors[:reverse_each_vs_reverse_each].count).to eq(2)
  end
end
