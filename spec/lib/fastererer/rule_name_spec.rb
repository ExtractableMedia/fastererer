# frozen_string_literal: true

require 'spec_helper'

describe Fastererer::RuleName do
  describe '.from' do
    it 'derives a PascalCase Performance/* name from a multi-word symbol' do
      expect(described_class.from(:select_first_vs_detect)).to eq('Performance/SelectFirstVsDetect')
    end

    it 'handles single-word rule names' do
      expect(described_class.from(:module_eval)).to eq('Performance/ModuleEval')
    end

    it 'accepts a string key' do
      expect(described_class.from('for_loop_vs_each')).to eq('Performance/ForLoopVsEach')
    end

    it 'skips empty parts produced by doubled underscores' do
      expect(described_class.from(:foo__bar)).to eq('Performance/FooBar')
    end
  end
end
