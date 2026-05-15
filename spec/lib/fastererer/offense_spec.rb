# frozen_string_literal: true

require 'spec_helper'

describe Fastererer::Offense do
  describe '#initialize' do
    it 'raises UnknownRuleError when offense_name is unknown' do
      expect { described_class.new(:no_such_rule, 1) }
        .to raise_error(Fastererer::Explanation::UnknownRuleError)
    end

    it 'stores offense_name when the rule is known' do
      offense = described_class.new(:for_loop_vs_each, 42)

      expect(offense.offense_name).to eq(:for_loop_vs_each)
    end

    it 'stores line_number when the rule is known' do
      offense = described_class.new(:for_loop_vs_each, 42)

      expect(offense.line_number).to eq(42)
    end
  end

  describe '#explanation' do
    it 'returns a Fastererer::Explanation for the offense' do
      offense = described_class.new(:for_loop_vs_each, 1)

      expect(offense.explanation).to be_a(Fastererer::Explanation)
    end

    it 'returns an Explanation whose offense_name matches the offense' do
      offense = described_class.new(:for_loop_vs_each, 1)

      expect(offense.explanation.offense_name).to eq(:for_loop_vs_each)
    end

    it 'memoizes the explanation instance' do
      offense = described_class.new(:for_loop_vs_each, 1)
      first_call = offense.explanation
      second_call = offense.explanation

      expect(first_call).to be(second_call)
    end
  end
end
