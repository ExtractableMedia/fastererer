require 'spec_helper'

describe Fastererer::Analyzer do
  let(:test_file_path) { RSpec.root.join('support', 'analyzer', '98_misc.rb') }

  it 'should detect gsub 4 times' do
    analyzer = Fastererer::Analyzer.new(test_file_path)
    analyzer.scan
  end
end
