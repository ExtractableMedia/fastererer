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

    it 'skips empty parts produced by doubled underscores' do
      explanation = described_class.new(:for_loop_vs_each)

      expect(explanation.send(:pascal_case, :foo__bar)).to eq('FooBar')
    end
  end

  describe '#offense_name' do
    it 'is stored as a symbol when constructed with a string' do
      expect(described_class.new('for_loop_vs_each').offense_name).to eq(:for_loop_vs_each)
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

    it 'does not double-print the period when description already ends with one' do
      explanation = described_class.new(:for_loop_vs_each)
      explanation.instance_variable_set(:@row,
                                        'description' => 'Sample.', 'url' => 'https://example.test/')

      expect(explanation.to_s).to eq('Performance/ForLoopVsEach: Sample. (https://example.test/)')
    end
  end

  describe 'with an unknown rule' do
    it 'raises UnknownRuleError naming the offending key' do
      expect { described_class.new(:no_such_rule) }
        .to raise_error(described_class::UnknownRuleError, /Unknown rule: :no_such_rule/)
    end
  end

  describe '.for' do
    it 'returns the same instance for the same offense_name' do
      first = described_class.for(:for_loop_vs_each)
      second = described_class.for(:for_loop_vs_each)

      expect(first).to be(second)
    end

    it 'shares the cached instance between symbol and string keys' do
      expect(described_class.for(:for_loop_vs_each))
        .to be(described_class.for('for_loop_vs_each'))
    end

    it 'raises UnknownRuleError on an unknown rule' do
      expect { described_class.for(:no_such_rule) }
        .to raise_error(described_class::UnknownRuleError, /Unknown rule: :no_such_rule/)
    end
  end

  describe '.validate!' do
    it 'returns the rule row when the key exists' do
      expect(described_class.validate!(:for_loop_vs_each)).to include('description', 'url')
    end

    it 'raises UnknownRuleError without instantiating an Explanation' do
      expect { described_class.validate!(:no_such_rule) }
        .to raise_error(described_class::UnknownRuleError, /Unknown rule: :no_such_rule/)
    end
  end

  describe '.rules' do
    it 'returns the same memoized hash on repeated calls' do
      first_call = described_class.rules
      second_call = described_class.rules

      expect(first_call).to be(second_call)
    end

    it 'returns a frozen top-level hash' do
      expect(described_class.rules).to be_frozen
    end

    it 'returns frozen row hashes' do
      expect(described_class.rules.values).to all(be_frozen)
    end

    it 'returns frozen description and url strings' do
      strings = described_class.rules.values.flat_map(&:values)

      expect(strings).to all(be_frozen)
    end
  end

  describe 'rule catalog' do
    it 'contains exactly 19 rules' do
      expect(described_class.rules.size).to eq(19)
    end

    it 'each rule has a String description' do
      described_class.rules.each do |key, row|
        expect(row['description']).to be_a(String), "#{key} description must be a String"
      end
    end

    it 'each rule description is non-empty' do
      described_class.rules.each do |key, row|
        expect(row['description']).not_to be_empty, "#{key} description is empty"
      end
    end

    it 'each rule links to a fast-ruby anchor' do
      described_class.rules.each do |key, row|
        expect(row['url']).to start_with('https://github.com/JuanitoFatas/fast-ruby#'),
                              "#{key} url does not point at fast-ruby: #{row['url'].inspect}"
      end
    end
  end
end
