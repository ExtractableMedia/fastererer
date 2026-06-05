# frozen_string_literal: true

require 'spec_helper'

describe Fastererer::Analyzer do
  subject(:analyzer) { described_class.new(test_file_path) }

  let(:test_file_path) { RSpec.root.join('support', 'analyzer', '27_setter_vs_attr_writer.rb') }

  before { analyzer.scan }

  it 'detects 2 setters' do
    expect(analyzer.errors[:setter_vs_attr_writer].count).to eq(2)
  end

  context 'with a setter body wrapped in rescue/ensure' do
    let(:test_file_path) do
      RSpec.root.join('support', 'analyzer', '27_setter_vs_attr_writer_with_rescue_body.rb')
    end

    it 'detects the setter inside the begin body' do
      expect(analyzer.errors[:setter_vs_attr_writer].count).to eq(1)
    end
  end
end
