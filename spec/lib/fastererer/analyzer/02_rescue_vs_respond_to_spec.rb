# frozen_string_literal: true

require 'spec_helper'

describe Fastererer::Analyzer do
  subject(:analyzer) { described_class.new(test_file_path) }

  let(:test_file_path) { RSpec.root.join('support', 'analyzer', '02_rescue_vs_respond_to.rb') }

  before { analyzer.scan }

  it 'detects rescue NoMethodError' do
    expect(analyzer.errors[:rescue_vs_respond_to].count).to eq(3)
  end
end
