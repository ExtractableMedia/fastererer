# frozen_string_literal: true

require 'spec_helper'

describe Fastererer::Analyzer do
  let(:test_file_path) { RSpec.root.join('support', 'analyzer', '98_misc.rb') }

  it 'detects gsub 4 times' do
    analyzer = described_class.new(test_file_path)
    analyzer.scan
  end
end
