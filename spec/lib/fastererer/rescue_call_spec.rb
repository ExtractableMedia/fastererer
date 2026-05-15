# frozen_string_literal: true

require 'spec_helper'

describe Fastererer::RescueCall do
  let(:file_path) { RSpec.root.join('support', 'rescue_call', file_name) }

  let(:rescue_element) do
    parsed = Fastererer::Parser.parse(File.read(file_path))
    parsed.value.statements.body.first.rescue_clause
  end

  let(:rescue_call) { described_class.new(rescue_element) }

  describe 'plain rescue call' do
    let(:file_name) { 'plain_rescue.rb' }

    it 'has no rescue classes' do
      expect(rescue_call.rescue_classes).to eq([])
    end
  end

  describe 'rescue call with class' do
    let(:file_name) { 'rescue_with_class.rb' }

    it 'detects rescue class' do
      expect(rescue_call.rescue_classes).to eq([:NoMethodError])
    end
  end

  describe 'rescue call with class and variable' do
    let(:file_name) { 'rescue_with_class_and_variable.rb' }

    it 'detects rescue class' do
      expect(rescue_call.rescue_classes).to eq([:NoMethodError])
    end
  end

  describe 'rescue call with variable' do
    let(:file_name) { 'rescue_with_variable.rb' }

    it 'has no rescue classes' do
      expect(rescue_call.rescue_classes).to eq([])
    end
  end

  describe 'rescue call with multiple classes' do
    let(:file_name) { 'rescue_with_multiple_classes.rb' }

    it 'detects all rescue classes' do
      expect(rescue_call.rescue_classes).to eq(%i[NoMethodError StandardError])
    end
  end

  describe 'rescue call with multiple classes and variable' do
    let(:file_name) { 'rescue_with_multiple_classes_and_variable.rb' }

    it 'detects all rescue classes' do
      expect(rescue_call.rescue_classes).to eq(%i[NoMethodError StandardError])
    end
  end

  describe 'rescue call with namespaced class' do
    let(:file_name) { 'rescue_with_namespaced_class.rb' }

    it 'detects namespaced rescue class' do
      expect(rescue_call.rescue_classes).to eq([:RecordNotFound])
    end
  end

  describe 'rescue call with mixed simple and namespaced classes' do
    let(:file_name) { 'rescue_with_mixed_classes.rb' }

    it 'detects all rescue classes' do
      expect(rescue_call.rescue_classes).to eq(%i[NoMethodError RecordNotFound])
    end
  end
end
