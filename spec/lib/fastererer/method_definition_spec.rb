# frozen_string_literal: true

require 'spec_helper'

describe Fastererer::MethodDefinition do
  let(:def_element) do
    parsed = Fastererer::Parser.parse(
      File.read(RSpec.root.join('support', 'method_definition', file_name))
    )
    parsed.value.statements.body.first
  end

  let(:method_definition) { described_class.new(def_element) }

  describe 'method with no arguments' do
    let(:file_name) { 'simple_method.rb' }

    it 'does not detect block', :aggregate_failures do
      expect(method_definition.method_name).to eq(:hello)
      expect(method_definition.block?).to be(false)
    end
  end

  describe 'method with no arguments and omitted parenthesis' do
    let(:file_name) { 'simple_method_omitted_parenthesis.rb' }

    it 'does not detect block', :aggregate_failures do
      expect(method_definition.method_name).to eq(:hello)
      expect(method_definition.block?).to be(false)
    end
  end

  describe 'method with one argument' do
    let(:file_name) { 'simple_method_with_argument.rb' }

    it 'does not detect block', :aggregate_failures do
      expect(method_definition.method_name).to eq(:hello)
      expect(method_definition.block?).to be(false)
    end
  end

  describe 'method with a block' do
    let(:file_name) { 'method_with_block.rb' }

    it 'detects block', :aggregate_failures do
      expect(method_definition.method_name).to eq(:hello)
      expect(method_definition.block?).to be(true)
      expect(method_definition.block_argument_name).to eq(:block)
    end
  end

  describe 'method with an argument and a block' do
    let(:file_name) { 'method_with_argument_and_block.rb' }

    it 'detects block', :aggregate_failures do
      expect(method_definition.method_name).to eq(:hello)
      expect(method_definition.block?).to be(true)
      expect(method_definition.block_argument_name).to eq(:block)
    end
  end

  describe 'method with an splat argument and a block' do
    let(:file_name) { 'method_with_splat_and_block.rb' }

    it 'detects block', :aggregate_failures do
      expect(method_definition.method_name).to eq(:hello)
      expect(method_definition.block?).to be(true)
      expect(method_definition.block_argument_name).to eq(:block)
    end
  end

  describe 'method with an default argument' do
    let(:file_name) { 'method_with_default_argument.rb' }

    it 'does not detect block', :aggregate_failures do
      expect(method_definition.method_name).to eq(:hello)
      expect(method_definition.block?).to be(false)
    end

    it 'detects default argument type', :aggregate_failures do
      arg = method_definition.arguments.first
      expect(arg).to be_default_argument
      expect(arg).not_to be_regular_argument
      expect(arg).not_to be_keyword_argument
    end
  end

  describe 'method with a keyword argument' do
    let(:file_name) { 'method_with_keyword_argument.rb' }

    it 'detects keyword argument type', :aggregate_failures do
      arg = method_definition.arguments.first
      expect(arg).to be_keyword_argument
      expect(arg).not_to be_regular_argument
      expect(arg).not_to be_default_argument
    end
  end

  describe 'method with a regular argument' do
    let(:file_name) { 'simple_method_with_argument.rb' }

    it 'detects regular argument type', :aggregate_failures do
      arg = method_definition.arguments.first
      expect(arg).to be_regular_argument
      expect(arg).not_to be_default_argument
      expect(arg).not_to be_keyword_argument
    end
  end

  describe 'method with a destructured argument' do
    let(:file_name) { 'method_with_destructured_argument.rb' }

    it 'represents the destructured argument with a nil name', :aggregate_failures do
      destructured, regular = method_definition.arguments
      expect(destructured.name).to be_nil
      expect(regular.name).to eq(:c)
    end
  end
end
