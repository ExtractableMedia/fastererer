# frozen_string_literal: true

require 'spec_helper'

describe Fastererer::MethodDefinition do
  include ParserHelpers

  let(:def_element) do
    parse_first_statement(File.read(RSpec.root.join('support', 'method_definition', file_name)))
  end

  let(:method_definition) { described_class.new(def_element) }

  context 'with no arguments' do
    let(:file_name) { 'simple_method.rb' }

    it 'does not detect block', :aggregate_failures do
      expect(method_definition.method_name).to eq(:hello)
      expect(method_definition.block?).to be(false)
    end
  end

  context 'with no arguments and omitted parentheses' do
    let(:file_name) { 'simple_method_omitted_parenthesis.rb' }

    it 'does not detect block', :aggregate_failures do
      expect(method_definition.method_name).to eq(:hello)
      expect(method_definition.block?).to be(false)
    end
  end

  context 'with one argument' do
    let(:file_name) { 'simple_method_with_argument.rb' }

    it 'does not detect block', :aggregate_failures do
      expect(method_definition.method_name).to eq(:hello)
      expect(method_definition.block?).to be(false)
    end
  end

  context 'with a block' do
    let(:file_name) { 'method_with_block.rb' }

    it 'detects block', :aggregate_failures do
      expect(method_definition.method_name).to eq(:hello)
      expect(method_definition.block?).to be(true)
      expect(method_definition.block_argument_name).to eq(:block)
    end
  end

  context 'with an argument and a block' do
    let(:file_name) { 'method_with_argument_and_block.rb' }

    it 'detects block', :aggregate_failures do
      expect(method_definition.method_name).to eq(:hello)
      expect(method_definition.block?).to be(true)
      expect(method_definition.block_argument_name).to eq(:block)
    end
  end

  context 'with a splat argument and a block' do
    let(:file_name) { 'method_with_splat_and_block.rb' }

    it 'detects block', :aggregate_failures do
      expect(method_definition.method_name).to eq(:hello)
      expect(method_definition.block?).to be(true)
      expect(method_definition.block_argument_name).to eq(:block)
    end

    it 'includes the splat and block among its arguments' do
      expect(method_definition.arguments.map(&:name)).to eq(%i[name surname other_names block])
    end
  end

  context 'with a post argument after a splat' do
    let(:file_name) { 'method_with_post_argument.rb' }

    it 'includes the splat and the post argument among its arguments' do
      expect(method_definition.arguments.map(&:name)).to eq(%i[names last])
    end
  end

  context 'with a keyword-rest argument' do
    let(:file_name) { 'method_with_keyword_rest.rb' }

    it 'includes the keyword-rest argument among its arguments' do
      expect(method_definition.arguments.map(&:name)).to eq(%i[options])
    end
  end

  context 'with a default argument' do
    let(:file_name) { 'method_with_default_argument.rb' }

    it 'does not detect block', :aggregate_failures do
      expect(method_definition.method_name).to eq(:hello)
      expect(method_definition.block?).to be(false)
    end

    it 'detects the default argument type', :aggregate_failures do
      arg = method_definition.arguments.first
      expect(arg).to be_default_argument
      expect(arg).not_to be_regular_argument
      expect(arg).not_to be_keyword_argument
    end
  end

  context 'with a keyword argument' do
    let(:file_name) { 'method_with_keyword_argument.rb' }

    it 'detects the keyword argument type', :aggregate_failures do
      arg = method_definition.arguments.first
      expect(arg).to be_keyword_argument
      expect(arg).not_to be_regular_argument
      expect(arg).not_to be_default_argument
    end
  end

  context 'with a regular argument' do
    let(:file_name) { 'simple_method_with_argument.rb' }

    it 'detects the regular argument type', :aggregate_failures do
      arg = method_definition.arguments.first
      expect(arg).to be_regular_argument
      expect(arg).not_to be_default_argument
      expect(arg).not_to be_keyword_argument
    end
  end

  context 'with a destructured argument' do
    let(:file_name) { 'method_with_destructured_argument.rb' }

    it 'represents the destructured argument with a nil name', :aggregate_failures do
      destructured, regular = method_definition.arguments
      expect(destructured.name).to be_nil
      expect(regular.name).to eq(:c)
    end

    it 'classifies the destructured argument as none of the known types', :aggregate_failures do
      destructured = method_definition.arguments.first
      expect(destructured).not_to be_regular_argument
      expect(destructured).not_to be_default_argument
      expect(destructured).not_to be_keyword_argument
    end
  end
end
