# frozen_string_literal: true

require 'spec_helper'

describe Fastererer::Analyzer do
  subject(:analyzer) { described_class.new(test_file_path) }

  let(:test_file_path) do
    RSpec.root.join('support', 'analyzer', '25_select_last_vs_reverse_detect.rb')
  end

  before { analyzer.scan }

  it 'detects select last once' do
    expect(analyzer.errors[:select_last_vs_reverse_detect].count).to eq(1)
  end
end
