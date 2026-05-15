# frozen_string_literal: true

require 'spec_helper'

describe Fastererer::Analyzer do
  let(:test_file_path) { RSpec.root.join('support', 'analyzer', '98_misc.rb') }

  it 'scans without raising' do
    analyzer = described_class.new(test_file_path)
    expect { analyzer.scan }.not_to raise_error
  end
end
