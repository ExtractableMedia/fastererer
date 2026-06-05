# frozen_string_literal: true

require 'spec_helper'

describe Fastererer::Analyzer do
  subject(:analyzer) { described_class.new(test_file_path) }

  let(:test_file_path) { RSpec.root.join('support', 'analyzer', '19_proc_call_vs_yield.rb') }

  before { analyzer.scan }

  it 'flags only the methods whose block parameter is invoked with call' do
    offending_lines = analyzer.errors[:proc_call_vs_yield].map(&:line_number)
    expect(offending_lines).to contain_exactly(2, 11, 22, 27)
  end

  context 'with a block call inside a nested method definition' do
    let(:test_file_path) do
      RSpec.root.join('support', 'analyzer', '19_proc_call_vs_yield_nested_def.rb')
    end

    it 'attributes the offense to the inner method only' do
      expect(analyzer.errors[:proc_call_vs_yield].map(&:line_number)).to contain_exactly(2)
    end
  end

  context 'with a block call inside a singleton class opened in the method' do
    let(:test_file_path) do
      RSpec.root.join('support', 'analyzer', '19_proc_call_vs_yield_in_singleton_class.rb')
    end

    it 'does not attribute the singleton-scope call to the method' do
      expect(analyzer.errors[:proc_call_vs_yield]).to be_empty
    end
  end

  context 'with a method body wrapped in rescue/ensure' do
    let(:test_file_path) do
      RSpec.root.join('support', 'analyzer', '19_proc_call_vs_yield_with_rescue_body.rb')
    end

    it 'detects the block call inside the begin body' do
      expect(analyzer.errors[:proc_call_vs_yield].map(&:line_number)).to contain_exactly(2)
    end
  end

  context 'with an anonymous block parameter' do
    let(:test_file_path) do
      RSpec.root.join('support', 'analyzer', '19_proc_call_vs_yield_anonymous_block.rb')
    end

    it 'does not attribute a local call to the unnamed block parameter' do
      expect(analyzer.errors[:proc_call_vs_yield]).to be_empty
    end
  end
end
