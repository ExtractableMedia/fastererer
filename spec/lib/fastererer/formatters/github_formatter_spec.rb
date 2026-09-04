# frozen_string_literal: true

require 'spec_helper'

describe Fastererer::Formatters::GithubFormatter do
  include FormatterHelpers

  subject(:formatter) { described_class.new(out: out, err: err) }

  let(:out) { StringIO.new }
  let(:err) { StringIO.new }
  let(:annotations) { out.string.lines(chomp: true) }

  describe '#render' do
    context 'with offenses' do
      let(:findings) do
        [finding(path: 'a.rb', line: 2, rule_key: 'aaa', description: 'Slow A'),
         finding(path: 'a.rb', line: 7, rule_key: 'bbb', description: 'Slow B'),
         finding(path: 'b.rb', line: 9, rule_key: 'aaa', description: 'Slow C')]
      end

      let(:expected_annotations) do
        ['::warning file=a.rb,line=2::aaa: Slow A',
         '::warning file=a.rb,line=7::bbb: Slow B',
         '::warning file=b.rb,line=9::aaa: Slow C']
      end

      before { formatter.render(report(findings: findings, inspected: 2)) }

      it 'emits one workflow command per offense, including repeats within one file' do
        expect(annotations).to eq(expected_annotations)
      end

      it 'excludes the statistics line' do
        expect(out.string).not_to include('files inspected')
      end
    end

    context 'with a path holding workflow-command separators' do
      let(:findings) { [finding(path: 'a,b:c%d.rb', line: 3, description: 'Slow')] }

      before { formatter.render(report(findings: findings, inspected: 1)) }

      it 'percent-encodes them so the property value survives' do
        expect(annotations.first).to start_with('::warning file=a%2Cb%3Ac%25d.rb,line=3::')
      end
    end

    context 'with a control character in the path' do
      let(:findings) { [finding(path: "ev\nil.rb", line: 3, description: 'Slow')] }

      before { formatter.render(report(findings: findings, inspected: 1)) }

      it 'escapes it so a crafted file name cannot open a second command' do
        expect(annotations).to eq(['::warning file=ev\\x0Ail.rb,line=3::slow_thing: Slow'])
      end
    end

    context 'with a description holding a percent' do
      let(:findings) { [finding(path: 'a.rb', line: 1, description: 'Use 100% less')] }

      before { formatter.render(report(findings: findings, inspected: 1)) }

      it 'percent-encodes it so the runner does not decode it' do
        expect(annotations.first).to end_with('::slow_thing: Use 100%25 less')
      end
    end

    context 'with a comma and colon in the description' do
      let(:findings) { [finding(path: 'a.rb', line: 1, description: 'Rescue it, use: x')] }

      before { formatter.render(report(findings: findings, inspected: 1)) }

      it 'leaves them raw, since only property values treat them as separators' do
        expect(annotations.first).to end_with('::slow_thing: Rescue it, use: x')
      end
    end

    context 'with a control character in the description' do
      let(:findings) { [finding(path: 'a.rb', line: 1, description: "Slow\nthing")] }

      before { formatter.render(report(findings: findings, inspected: 1)) }

      it 'escapes it, keeping the command on a single line' do
        expect(annotations).to eq(['::warning file=a.rb,line=1::slow_thing: Slow\\x0Athing'])
      end
    end

    context 'with no offenses' do
      before { formatter.render(report(inspected: 3)) }

      it 'writes zero bytes to stdout' do
        expect(out.string).to be_empty
      end
    end

    context 'with unparsable files' do
      before { formatter.render(report(inspected: 1, unparsable: ['bad.rb - Err - boom'])) }

      it 'routes them to stderr, keeping stdout clean', :aggregate_failures do
        expect(err.string).to include('bad.rb - Err - boom')
        expect(out.string).to be_empty
      end
    end
  end
end
