# frozen_string_literal: true

require 'spec_helper'

describe Fastererer::RuleCatalog do
  describe '.all' do
    it 'returns the same memoized hash on repeated calls' do
      first_call = described_class.all
      second_call = described_class.all

      expect(first_call).to be(second_call)
    end

    it 'returns a frozen top-level hash' do
      expect(described_class.all).to be_frozen
    end

    it 'returns frozen row hashes' do
      expect(described_class.all.values).to all(be_frozen)
    end

    it 'returns frozen description and url strings' do
      strings = described_class.all.values.flat_map(&:values)

      expect(strings).to all(be_frozen)
    end
  end

  describe '.fetch' do
    it 'returns the rule row when the key exists' do
      expect(described_class.fetch(:for_loop_vs_each)).to include('description', 'url')
    end

    it 'looks up symbol and string keys alike' do
      expect(described_class.fetch('for_loop_vs_each')).to include('description', 'url')
    end

    it 'raises UnknownRuleError when the key is unknown' do
      expect { described_class.fetch(:no_such_rule) }
        .to raise_error(Fastererer::UnknownRuleError, /Unknown rule: :no_such_rule/)
    end
  end

  describe '.validate!' do
    it 'returns nil for a known rule' do
      expect(described_class.validate!(:for_loop_vs_each)).to be_nil
    end

    it 'raises UnknownRuleError for an unknown rule' do
      expect { described_class.validate!(:no_such_rule) }
        .to raise_error(Fastererer::UnknownRuleError, /Unknown rule: :no_such_rule/)
    end
  end

  describe 'catalog integrity' do
    it 'contains the expected number of rules' do
      expect(described_class.all.size).to eq(19)
    end

    it 'each rule has a String description' do
      described_class.all.each do |key, row|
        expect(row['description']).to be_a(String), "#{key} description must be a String"
      end
    end

    it 'each rule description is non-empty' do
      described_class.all.each do |key, row|
        expect(row['description']).not_to be_empty, "#{key} description is empty"
      end
    end

    it 'each rule links to a fast-ruby anchor' do
      described_class.all.each do |key, row|
        expect(row['url']).to start_with('https://github.com/fastruby/fast-ruby#'),
                              "#{key} url does not point at fast-ruby: #{row['url'].inspect}"
      end
    end

    it 'no description ends with a terminal period' do
      described_class.all.each do |key, row|
        expect(row['description']).not_to end_with('.'), "#{key} description ends with a period"
      end
    end

    it 'every description and url is printable', :aggregate_failures do
      described_class.all.each do |key, row|
        expect(row['description']).to match(/\A[[:print:][:space:]]+\z/), "#{key} description"
        expect(row['url']).to match(/\A[[:print:]]+\z/), "#{key} url"
      end
    end

    it 'no url contains a closing parenthesis' do
      described_class.all.each do |key, row|
        expect(row['url']).not_to include(')'), "#{key} url contains a closing parenthesis"
      end
    end
  end

  describe 'when the catalog cannot be loaded' do
    before { described_class.send(:reset!) }
    after { described_class.send(:reset!) }

    it 'raises a clear error when the locale file is missing' do
      allow(YAML).to receive(:safe_load_file).and_raise(Errno::ENOENT)

      expect { described_class.all }.to raise_error(/locale file not found/)
    end

    it 'raises a clear error when the rules section is absent' do
      allow(YAML).to receive(:safe_load_file).and_return('en' => {})

      expect { described_class.all }.to raise_error(/missing the 'en.fastererer.rules' section/)
    end

    it 'raises the section error rather than NoMethodError when the file is empty' do
      allow(YAML).to receive(:safe_load_file).and_return(nil)

      expect { described_class.all }.to raise_error(/missing the 'en.fastererer.rules' section/)
    end

    it 'raises a clear error when the file is not valid YAML' do
      allow(YAML).to receive(:safe_load_file)
        .and_raise(Psych::SyntaxError.new(described_class::LOCALE_PATH, 1, 1, 0, 'bad', nil))

      expect { described_class.all }.to raise_error(/is not valid YAML/)
    end

    it 'raises when a rule url is not https' do
      allow(YAML).to receive(:safe_load_file).and_return(locale_with(url: 'javascript:alert(1)'))

      expect { described_class.all }.to raise_error(/non-https url/)
    end

    it 'raises when a rule url has non-printable characters' do
      allow(YAML).to receive(:safe_load_file).and_return(locale_with(url: "https://ok/\e[0m"))

      expect { described_class.all }.to raise_error(/non-printable url/)
    end

    it 'raises when a rule entry is not a hash' do
      malformed = { 'en' => { 'fastererer' => { 'rules' => { 'only_rule' => 'oops' } } } }
      allow(YAML).to receive(:safe_load_file).and_return(malformed)

      expect { described_class.all }.to raise_error(/rule only_rule is malformed/)
    end

    private

    def locale_with(url:, description: 'A description')
      row = { 'description' => description, 'url' => url }
      { 'en' => { 'fastererer' => { 'rules' => { 'only_rule' => row } } } }
    end
  end
end
