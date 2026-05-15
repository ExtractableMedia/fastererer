# frozen_string_literal: true

require 'spec_helper'

describe Fastererer::Explanation do
  describe '#description' do
    it 'returns the localized description for the rule' do
      explanation = described_class.new(:for_loop_vs_each)

      expect(explanation.description).to eq('For loop is slower than using each')
    end
  end

  describe '#url' do
    it 'returns the fast-ruby documentation link' do
      explanation = described_class.new(:select_first_vs_detect)

      expect(explanation.url).to start_with('https://github.com/JuanitoFatas/fast-ruby#')
    end
  end

  describe '#rule_name' do
    it 'derives a PascalCase Performance/* name from the symbol key' do
      explanation = described_class.new(:select_first_vs_detect)

      expect(explanation.rule_name).to eq('Performance/SelectFirstVsDetect')
    end

    it 'handles single-word rule names' do
      explanation = described_class.new(:module_eval)

      expect(explanation.rule_name).to eq('Performance/ModuleEval')
    end
  end

  describe '#to_s' do
    it 'renders rule name, description, and URL in rubocop style' do
      rendered = described_class.new(:for_loop_vs_each).to_s

      expect(rendered).to eq(
        'Performance/ForLoopVsEach: For loop is slower than using each. ' \
        '(https://github.com/JuanitoFatas/fast-ruby#enumerableeach-vs-for-loop-code)'
      )
    end
  end

  describe 'with an unknown rule' do
    it 'raises UnknownRuleError' do
      expect { described_class.new(:no_such_rule) }
        .to raise_error(described_class::UnknownRuleError, /no_such_rule/)
    end
  end
end
