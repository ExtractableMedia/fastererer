require 'spec_helper'

describe Fastererer::Analyzer do
  let(:test_file_path) { RSpec.root.join('support', 'analyzer', '24_gsub_vs_tr.rb') }

  it 'should detect gsub 4 times' do
    analyzer = Fastererer::Analyzer.new(test_file_path)
    analyzer.scan
    expect(analyzer.errors[:gsub_vs_tr].count).to eq(2)
  end
end
