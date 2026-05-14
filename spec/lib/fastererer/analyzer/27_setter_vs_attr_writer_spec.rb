# frozen_string_literal: true

require 'spec_helper'

describe Fastererer::Analyzer do
  let(:test_file_path) { RSpec.root.join('support', 'analyzer', '27_setter_vs_attr_writer.rb') }

  it 'detects 2 setters' do
    analyzer = described_class.new(test_file_path)
    analyzer.scan
    expect(analyzer.errors[:setter_vs_attr_writer].count).to eq(2)
  end
end
