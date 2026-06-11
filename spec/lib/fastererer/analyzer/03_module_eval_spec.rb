# frozen_string_literal: true

require 'spec_helper'

describe Fastererer::Analyzer do
  subject(:analyzer) { described_class.new(test_file_path) }

  let(:test_file_path) { RSpec.root.join('support', 'analyzer', '03_module_eval.rb') }

  before { analyzer.scan }

  it 'detects module eval' do
    expect(analyzer.errors[:module_eval].count).to eq(1)
  end
end
