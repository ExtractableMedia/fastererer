# frozen_string_literal: true

require 'spec_helper'

describe Fastererer::Finding do
  describe '.from' do
    let(:offense) { Fastererer::Offense.new(:shuffle_first_vs_sample, 7) }
    let(:finding) { described_class.from(offense, path) }

    context 'with a scannable path' do
      let(:path) { 'app/user.rb' }

      let(:expected_attributes) do
        {
          path: 'app/user.rb',
          line: 7,
          rule_key: 'shuffle_first_vs_sample',
          rule_name: 'Performance/ShuffleFirstVsSample'
        }
      end

      it 'carries the offense line and its catalog explanation' do
        expect(finding).to have_attributes(expected_attributes)
      end
    end

    context 'with invalid bytes in the path' do
      let(:path) { "app/ba\xFFd.rb" }

      it 'replaces them so a serializer cannot raise on it' do
        expect(finding.path).to eq('app/ba�d.rb')
      end
    end
  end
end
