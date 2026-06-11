# frozen_string_literal: true

require 'spec_helper'

describe Fastererer::Analyzer do
  subject(:analyzer) { described_class.new(test_file_path) }

  let(:test_file_path) { RSpec.root.join('support', 'analyzer', '26_getter_vs_attr_reader.rb') }

  before { analyzer.scan }

  it 'detects 2 getters' do
    expect(analyzer.errors[:getter_vs_attr_reader].count).to eq(2)
  end

  context 'with a getter body wrapped in rescue/ensure' do
    let(:test_file_path) do
      RSpec.root.join('support', 'analyzer', '26_getter_vs_attr_reader_with_rescue_body.rb')
    end

    it 'detects the getter inside the begin body' do
      expect(analyzer.errors[:getter_vs_attr_reader].count).to eq(1)
    end
  end
end
