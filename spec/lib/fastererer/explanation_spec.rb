# frozen_string_literal: true

require 'spec_helper'

describe Fastererer::Explanation do
  describe '.for' do
    it 'returns the same instance for the same offense_name' do
      first = described_class.for(:for_loop_vs_each)
      second = described_class.for(:for_loop_vs_each)

      expect(first).to be(second)
    end

    it 'shares the cached instance between symbol and string keys' do
      expect(described_class.for(:for_loop_vs_each)).to be(described_class.for('for_loop_vs_each'))
    end

    it 'raises UnknownRuleError on an unknown rule' do
      expect { described_class.for(:no_such_rule) }
        .to raise_error(Fastererer::UnknownRuleError, /Unknown rule: :no_such_rule/)
    end
  end

  describe '#offense_name' do
    it 'is stored as a symbol when constructed with a string' do
      expect(described_class.new('for_loop_vs_each').offense_name).to eq(:for_loop_vs_each)
    end
  end

  describe '#initialize' do
    it 'raises UnknownRuleError naming the offending key' do
      expect { described_class.new(:no_such_rule) }
        .to raise_error(Fastererer::UnknownRuleError, /Unknown rule: :no_such_rule/)
    end
  end

  describe '#description' do
    it 'returns the localized description for the rule' do
      explanation = described_class.new(:for_loop_vs_each)

      expect(explanation.description).to eq('For loop is slower than using each')
    end
  end

  describe '#url' do
    it 'returns the fast-ruby documentation link' do
      explanation = described_class.new(:select_first_vs_detect)

      expect(explanation.url).to start_with('https://github.com/fastruby/fast-ruby#')
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
        '(https://github.com/fastruby/fast-ruby#enumerableeach-vs-for-loop-code)'
      )
    end

    it 'does not double-print the period when description already ends with one' do
      allow(Fastererer::RuleCatalog).to receive(:fetch)
        .and_return('description' => 'Sample.', 'url' => 'https://example.test/')

      expect(described_class.new(:for_loop_vs_each).to_s)
        .to eq('Performance/ForLoopVsEach: Sample. (https://example.test/)')
    end
  end
end
