# frozen_string_literal: true

require 'spec_helper'

describe Fastererer::Analyzer do
  subject(:analyzer) { described_class.new(test_file_path) }

  let(:test_file_path) do
    RSpec.root.join('support', 'analyzer', '16_hash_merge_bang_vs_hash_brackets.rb')
  end

  before { analyzer.scan }

  it 'flags merge! and flags its update alias only on a provably-Hash receiver' do
    offenses = analyzer.errors[:hash_merge_bang_vs_hash_brackets]
    expect(offenses.map(&:line_number)).to contain_exactly(10, 17, 19, 23, 25, 27, 39, 41, 43, 45)
  end
end
