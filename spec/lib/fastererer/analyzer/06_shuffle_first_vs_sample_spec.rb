require 'spec_helper'

describe Fastererer::Analyzer do
  let(:test_file_path) { RSpec.root.join('support', 'analyzer', '06_shuffle_first_vs_sample.rb') }

  it 'should detect a for loop' do
    analyzer = Fastererer::Analyzer.new(test_file_path)
    analyzer.scan
    expect(analyzer.errors[:shuffle_first_vs_sample].count).to eq(5)
  end
end
