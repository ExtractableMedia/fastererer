require 'spec_helper'

describe Fastererer::Analyzer do
  let(:test_file_path) { RSpec.root.join('support', 'analyzer', '16_hash_merge_bang_vs_hash_brackets.rb') }

  it 'should detect keys each 3 times' do
    analyzer = Fastererer::Analyzer.new(test_file_path)
    analyzer.scan
    expect(analyzer.errors[:hash_merge_bang_vs_hash_brackets].count).to eq(3)
  end
end
