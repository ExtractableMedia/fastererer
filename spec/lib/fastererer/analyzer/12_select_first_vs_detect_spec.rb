require 'spec_helper'

describe Fastererer::Analyzer do
  let(:test_file_path) { RSpec.root.join('support', 'analyzer', '12_select_first_vs_detect.rb') }

  it 'should detect sort once' do
    analyzer = Fastererer::Analyzer.new(test_file_path)
    analyzer.scan
    expect(analyzer.errors[:select_first_vs_detect].count).to eq(3)
  end
end
