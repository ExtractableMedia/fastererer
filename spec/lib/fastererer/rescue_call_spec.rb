# frozen_string_literal: true

require 'spec_helper'

describe Fastererer::RescueCall do
  let(:file_path) { RSpec.root.join('support', 'rescue_call', file_name) }

  let(:rescue_element) do
    sexpd_file = Fastererer::Parser.parse(File.read(file_path))
    sexpd_file[2]
  end

  let(:rescue_call) do
    described_class.new(rescue_element)
  end

  describe 'plain rescue call' do
    let(:file_name) { 'plain_rescue.rb' }

    it 'detects constant' do
      expect(rescue_call.rescue_classes).to eq(Sexp.new)
    end
  end

  describe 'rescue call with class' do
    let(:file_name) { 'rescue_with_class.rb' }

    it 'detects integer' do
      expect(rescue_call.rescue_classes).to eq(Sexp.new(:NoMethodError))
    end
  end

  describe 'rescue call with class and variable' do
    let(:file_name) { 'rescue_with_class_and_variable.rb' }

    it 'detects string' do
      expect(rescue_call.rescue_classes).to eq(Sexp.new(:NoMethodError))
    end
  end

  describe 'rescue call with variable' do
    let(:file_name) { 'rescue_with_variable.rb' }

    it 'detects variable' do
      expect(rescue_call.rescue_classes).to eq(Sexp.new)
    end
  end

  describe 'rescue call with multiple classes' do
    let(:file_name) { 'rescue_with_multiple_classes.rb' }

    it 'detects method' do
      expect(rescue_call.rescue_classes).to eq(Sexp.new(:NoMethodError, :StandardError))
    end
  end

  describe 'rescue call with multiple classes and variable' do
    let(:file_name) { 'rescue_with_multiple_classes_and_variable.rb' }

    it 'detects method' do
      expect(rescue_call.rescue_classes).to eq(Sexp.new(:NoMethodError, :StandardError))
    end
  end
end
