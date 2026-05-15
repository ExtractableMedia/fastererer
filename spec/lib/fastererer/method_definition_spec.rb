# frozen_string_literal: true

require 'spec_helper'

describe Fastererer::MethodDefinition do
  let(:def_element) do
    Fastererer::Parser.parse(File.read(RSpec.root.join('support', 'method_definition', file_name)))
  end

  let(:method_definition) { described_class.new(def_element) }

  describe 'method with no arguments' do
    let(:file_name) { 'simple_method.rb' }

    it 'does not detect block' do
      expect(method_definition.method_name).to eq(:hello)
      expect(method_definition.has_block?).to be(false)
    end
  end

  describe 'method with no arguments and omitted parenthesis' do
    let(:file_name) { 'simple_method_omitted_parenthesis.rb' }

    it 'does not detect block' do
      expect(method_definition.method_name).to eq(:hello)
      expect(method_definition.has_block?).to be(false)
    end
  end

  describe 'method with one argument' do
    let(:file_name) { 'simple_method_with_argument.rb' }

    it 'does not detect block' do
      expect(method_definition.method_name).to eq(:hello)
      expect(method_definition.has_block?).to be(false)
    end
  end

  describe 'method with a block' do
    let(:file_name) { 'method_with_block.rb' }

    it 'detects block' do
      expect(method_definition.method_name).to eq(:hello)
      expect(method_definition.has_block?).to be(true)
      expect(method_definition.block_argument_name).to eq(:block)
    end
  end

  describe 'method with an argument and a block' do
    let(:file_name) { 'method_with_argument_and_block.rb' }

    it 'detects block' do
      expect(method_definition.method_name).to eq(:hello)
      expect(method_definition.has_block?).to be(true)
      expect(method_definition.block_argument_name).to eq(:block)
    end
  end

  describe 'method with an splat argument and a block' do
    let(:file_name) { 'method_with_splat_and_block.rb' }

    it 'detects block' do
      expect(method_definition.method_name).to eq(:hello)
      expect(method_definition.has_block?).to be(true)
      expect(method_definition.block_argument_name).to eq(:block)
    end
  end

  describe 'method with an default argument' do
    let(:file_name) { 'method_with_default_argument.rb' }

    it 'does not detect block' do
      expect(method_definition.method_name).to eq(:hello)
      expect(method_definition.has_block?).to be(false)
    end
  end
end
