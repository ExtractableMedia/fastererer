# frozen_string_literal: true

require 'spec_helper'

describe Fastererer::MethodCall do
  let(:ripper) do
    Fastererer::Parser.parse(code)
  end

  let(:method_call) do
    described_class.new(call_element)
  end

  describe 'with explicit receiver' do
    describe 'without arguments, without block, called with parentheses' do
      describe 'method call on a constant' do
        let(:code) { 'User.hello()' }

        # This is where the :call token will be recognized.
        let(:call_element) { ripper }

        it 'detects constant' do
          expect(method_call.method_name).to eq(:hello)
          expect(method_call.arguments).to be_empty
        end
      end

      describe 'method call on a integer' do
        let(:code) { '1.hello()' }

        # This is where the :call token will be recognized.
        let(:call_element) { ripper }

        it 'detects integer' do
          expect(method_call.method_name).to eq(:hello)
          expect(method_call.arguments).to be_empty
        end
      end

      describe 'method call on a string' do
        let(:code) { "'hello'.hello()" }

        let(:call_element) { ripper }

        it 'detects string' do
          expect(method_call.method_name).to eq(:hello)
          expect(method_call.arguments).to be_empty
        end
      end

      describe 'method call on a variable' do
        let(:code) do
          "number_one = 1\n" \
            'number_one.hello()'
        end

        let(:call_element) { ripper[2] }

        it 'detects variable' do
          expect(method_call.method_name).to eq(:hello)
          expect(method_call.arguments).to be_empty
          expect(method_call.receiver).to be_a(Fastererer::VariableReference)
          expect(method_call.receiver.name).to eq(:number_one)
        end
      end

      describe 'method call on a method' do
        let(:code) { '1.hi(2).hello()' }

        let(:call_element) { ripper }

        it 'detects method' do
          expect(method_call.method_name).to eq(:hello)
          expect(method_call.receiver).to be_a(described_class)
          expect(method_call.receiver.name).to eq(:hi)
          expect(method_call.arguments).to be_empty
        end
      end
    end

    describe 'without arguments, without block, called without parentheses' do
      describe 'method call on a constant' do
        let(:code) { 'User.hello' }

        let(:call_element) { ripper }

        it 'detects constant' do
          expect(method_call.method_name).to eq(:hello)
          expect(method_call.arguments).to be_empty
        end
      end

      describe 'method call on a integer' do
        let(:code) { '1.hello' }

        # This is where the :call token will be recognized.
        let(:call_element) { ripper }

        it 'detects integer' do
          expect(method_call.method_name).to eq(:hello)
          expect(method_call.arguments).to be_empty
        end
      end

      describe 'method call on a string' do
        let(:code) { "'hello'.hello" }

        let(:call_element) { ripper }

        it 'detects string' do
          expect(method_call.method_name).to eq(:hello)
          expect(method_call.arguments).to be_empty
        end
      end

      describe 'method call on a variable' do
        let(:code) do
          "number_one = 1\n" \
            'number_one.hello'
        end

        let(:call_element) { ripper[2] }

        it 'detects variable' do
          expect(method_call.method_name).to eq(:hello)
          expect(method_call.arguments).to be_empty
          expect(method_call.receiver).to be_a(Fastererer::VariableReference)
          expect(method_call.receiver.name).to eq(:number_one)
        end
      end

      describe 'method call on a method' do
        let(:code) { '1.hi(2).hello' }

        let(:call_element) { ripper }

        it 'detects method' do
          expect(method_call.method_name).to eq(:hello)
          expect(method_call.receiver).to be_a(described_class)
          expect(method_call.receiver.name).to eq(:hi)
          expect(method_call.arguments).to be_empty
        end
      end
    end

    describe 'with do end block' do
      describe 'and no arguments, without block parameter' do
        let(:code) do
          <<-CODE
            number_one.fetch do
              number_two = 2
              number_three = 3
            end
          CODE
        end

        let(:call_element) { ripper }

        it 'detects block' do
          expect(method_call.method_name).to eq(:fetch)
          expect(method_call.arguments).to be_empty
          expect(method_call.has_block?).to be
          expect(method_call.block_argument_names.count).to be(0)
          expect(method_call.receiver).to be_a(described_class)
        end
      end

      describe 'and no arguments, with block parameter' do
        let(:code) do
          <<-CODE
            number_one.fetch do |el|
              number_two = 2
              number_three = 3
            end
          CODE
        end

        let(:call_element) { ripper }

        it 'detects block' do
          expect(method_call.method_name).to eq(:fetch)
          expect(method_call.arguments).to be_empty
          expect(method_call.has_block?).to be
          expect(method_call.block_argument_names.count).to be(1)
          expect(method_call.block_argument_names.first).to be(:el)
          expect(method_call.receiver).to be_a(described_class)
        end
      end

      describe 'and no arguments, with block parameter' do
        let(:code) do
          <<-CODE
            number_one.fetch do |el, tip|
              number_two = 2
              number_three = 3
            end
          CODE
        end

        let(:call_element) { ripper }

        it 'detects block' do
          expect(method_call.method_name).to eq(:fetch)
          expect(method_call.arguments).to be_empty
          expect(method_call.has_block?).to be
          expect(method_call.block_argument_names.count).to be(2)
          expect(method_call.block_argument_names.first).to be(:el)
          expect(method_call.block_argument_names.last).to be(:tip)
          expect(method_call.receiver).to be_a(described_class)
        end
      end

      describe 'and one argument within parentheses' do
        let(:code) do
          <<-CODE
            number_one = 1
            number_one.fetch(100) do |el|
              number_two = 2
              number_three = 3
            end
          CODE
        end

        let(:call_element) { ripper[2] }

        it 'detects block' do
          expect(method_call.method_name).to eq(:fetch)
          expect(method_call.arguments.count).to be(1)
          expect(method_call.has_block?).to be
          expect(method_call.receiver).to be_a(Fastererer::VariableReference)
        end
      end
    end

    describe 'with curly block' do
      describe 'in one line' do
        let(:code) do
          <<-CODE
            number_one = 1
            number_one.fetch { |el| number_two = 2 }
          CODE
        end

        let(:call_element) { ripper[2] }

        it 'detects block' do
          expect(method_call.method_name).to eq(:fetch)
          expect(method_call.arguments).to be_empty
          expect(method_call.has_block?).to be
          expect(method_call.receiver).to be_a(Fastererer::VariableReference)
        end
      end

      describe 'multi lined' do
        let(:code) do
          <<-CODE
            number_one = 1
            number_one.fetch { |el|
              number_two = 2
              number_three = 3
            }
          CODE
        end

        let(:call_element) { ripper[2] }

        it 'detects block' do
          expect(method_call.method_name).to eq(:fetch)
          expect(method_call.arguments).to be_empty
          expect(method_call.has_block?).to be
          expect(method_call.receiver).to be_a(Fastererer::VariableReference)
        end
      end
    end

    describe 'with arguments, without block, called with parentheses' do
      describe 'method call with an argument' do
        let(:code) { '{}.fetch(:writing)' }

        let(:call_element) { ripper }

        it 'detects argument' do
          expect(method_call.method_name).to eq(:fetch)
          expect(method_call.arguments.count).to eq(1)
          expect(method_call.arguments.first.type).to eq(:lit)
        end
      end
    end

    describe 'arguments without parenthesis' do
      describe 'method call with an argument' do
        let(:code) { '{}.fetch :writing, :listening' }

        let(:call_element) { ripper }

        it 'detects argument' do
          expect(method_call.method_name).to eq(:fetch)
          expect(method_call.arguments.count).to eq(2)
          expect(method_call.arguments[0].type).to eq(:lit)
          expect(method_call.arguments[1].type).to eq(:lit)
        end
      end
    end
  end

  describe 'method call with an argument and a block' do
    let(:code) do
      <<-CODE
        number_one = 1
        number_one.fetch(:writing) { [*1..100] }
      CODE
    end

    let(:call_element) { ripper[2] }

    it 'detects argument and a block' do
      expect(method_call.method_name).to eq(:fetch)
      expect(method_call.arguments.count).to eq(1)
      expect(method_call.arguments.first.type).to eq(:lit)
      expect(method_call.has_block?).to be
      expect(method_call.receiver).to be_a(Fastererer::VariableReference)
    end
  end

  describe 'method call without an explicit receiver' do
    let(:code) { 'fetch(:writing, :listening)' }

    let(:call_element) { ripper }

    it 'detects two arguments' do
      expect(method_call.method_name).to eq(:fetch)
      expect(method_call.arguments.count).to eq(2)
      expect(method_call.arguments[0].type).to eq(:lit)
      expect(method_call.arguments[1].type).to eq(:lit)
      expect(method_call.receiver).to be_nil
    end
  end

  describe 'method call without an explicit receiver and without brackets' do
    let(:code) { 'fetch :writing, :listening' }

    let(:call_element) { ripper }

    it 'detects two arguments' do
      expect(method_call.method_name).to eq(:fetch)
      expect(method_call.arguments.count).to eq(2)
      expect(method_call.arguments[0].type).to eq(:lit)
      expect(method_call.arguments[1].type).to eq(:lit)
      expect(method_call.receiver).to be_nil
    end
  end

  describe 'method call without an explicit receiver and without brackets and do end' do
    let(:code) do
      <<-CODE
        "fetch :writing do\n"\
        "end"
      CODE
    end

    let(:call_element) { ripper.drop(1).first.first }

    it 'detects argument and a block' do
      # expect(method_call.method_name).to eq('fetch')
      # expect(method_call.arguments.count).to eq(2)
      # expect(method_call.arguments[0].type).to eq(:symbol_literal)
      # expect(method_call.arguments[1].type).to eq(:symbol_literal)
      # expect(method_call.receiver).to be_nil
    end
  end

  describe 'method call with two arguments' do
    let(:code) do
      "number_one = 1\n" \
        'number_one.fetch(:writing, :zumba)'
    end

    let(:call_element) { ripper[2] }

    it 'detects arguments' do
      expect(method_call.method_name).to eq(:fetch)
      expect(method_call.arguments.count).to eq(2)
      expect(method_call.arguments[0].type).to eq(:lit)
      expect(method_call.arguments[1].type).to eq(:lit)
      expect(method_call.receiver).to be_a(Fastererer::VariableReference)
    end
  end

  describe 'method call with a regex argument' do
    let(:code) { '{}.fetch(/.*/)' }

    let(:call_element) { ripper }

    it 'detects regex argument' do
      expect(method_call.method_name).to eq(:fetch)
      expect(method_call.arguments.count).to eq(1)
      expect(method_call.arguments[0].type).to eq(:lit)
      expect(method_call.arguments[0].value).to be_a(Regexp)
    end
  end

  describe 'method call with a integer argument' do
    let(:code) { '[].flatten(1)' }

    let(:call_element) { ripper }

    it 'detects regex argument' do
      expect(method_call.method_name).to eq(:flatten)
      expect(method_call.arguments.count).to eq(1)
      expect(method_call.arguments[0].type).to eq(:lit)
      expect(method_call.arguments[0].value).to eq(1)
    end
  end

  describe 'method call with symbol to proc argument' do
    let(:code) { '[].select(&:zero?)' }

    let(:call_element) { ripper }

    it 'detects block pass argument' do
      expect(method_call.method_name).to eq(:select)
      expect(method_call.arguments.count).to eq(1)
      expect(method_call.arguments[0].type).to eq(:block_pass)
      expect(method_call.has_block?).to be
    end
  end

  describe 'method call with equals operator' do
    let(:code) { 'method_call_with_equals.rb' }

    let(:call_element) { ripper.drop(1).first.first[1] }

    xit 'should recognize receiver' do
      # expect(method_call.method_name).to eq('hello')
      # expect(method_call.receiver).to be_a(Fastererer::MethodCall)
      # expect(method_call.receiver.name).to eq('hi')
    end
  end

  describe '#lambda_literal?' do
    describe 'lambda literal without arguments' do
      let(:code) { '-> {}' }

      let(:call_element) { ripper }

      it 'is true' do
        expect(method_call).to be_lambda_literal
      end
    end

    describe 'lambda literal with an argument' do
      let(:code) { '->(_) {}' }

      let(:call_element) { ripper }

      it 'is true' do
        expect(method_call).to be_lambda_literal
      end
    end

    describe 'lambda method' do
      let(:code) { 'lambda {}' }

      let(:call_element) { ripper }

      it 'is false' do
        expect(method_call).not_to be_lambda_literal
      end
    end
  end
end
