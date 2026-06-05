# frozen_string_literal: true

require 'spec_helper'

describe Fastererer::RescueCall do
  include ParserHelpers

  let(:file_path) { RSpec.root.join('support', 'rescue_call', file_name) }

  let(:rescue_element) do
    parse_first_statement(File.read(file_path)).rescue_clause
  end

  let(:rescue_call) { described_class.new(rescue_element) }

  context 'with a plain rescue' do
    let(:file_name) { 'plain_rescue.rb' }

    it 'has no rescue classes' do
      expect(rescue_call.rescue_classes).to eq([])
    end
  end

  context 'with a class' do
    let(:file_name) { 'rescue_with_class.rb' }

    it 'detects rescue class' do
      expect(rescue_call.rescue_classes).to eq([:NoMethodError])
    end
  end

  context 'with a class and a variable' do
    let(:file_name) { 'rescue_with_class_and_variable.rb' }

    it 'detects rescue class' do
      expect(rescue_call.rescue_classes).to eq([:NoMethodError])
    end
  end

  context 'with a variable' do
    let(:file_name) { 'rescue_with_variable.rb' }

    it 'has no rescue classes' do
      expect(rescue_call.rescue_classes).to eq([])
    end
  end

  context 'with multiple classes' do
    let(:file_name) { 'rescue_with_multiple_classes.rb' }

    it 'detects all rescue classes' do
      expect(rescue_call.rescue_classes).to eq(%i[NoMethodError StandardError])
    end
  end

  context 'with multiple classes and a variable' do
    let(:file_name) { 'rescue_with_multiple_classes_and_variable.rb' }

    it 'detects all rescue classes' do
      expect(rescue_call.rescue_classes).to eq(%i[NoMethodError StandardError])
    end
  end

  context 'with a namespaced class' do
    let(:file_name) { 'rescue_with_namespaced_class.rb' }

    it 'ignores namespaced rescue classes' do
      expect(rescue_call.rescue_classes).to eq([])
    end
  end

  context 'with mixed simple and namespaced classes' do
    let(:file_name) { 'rescue_with_mixed_classes.rb' }

    it 'detects only the unqualified rescue class' do
      expect(rescue_call.rescue_classes).to eq([:NoMethodError])
    end
  end
end
