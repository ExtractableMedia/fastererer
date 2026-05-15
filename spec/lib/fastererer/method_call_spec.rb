# frozen_string_literal: true

require 'spec_helper'

describe Fastererer::MethodCall do
  let(:ripper) { Fastererer::Parser.parse(code) }

  let(:method_call) { described_class.new(call_element) }

  context 'with explicit receiver' do
    context 'without arguments, without block, called with parentheses' do
      # rubocop:disable RSpec/NestedGroups
      context 'when the receiver is a constant' do
        let(:code) { 'User.hello()' }

        # This is where the :call token will be recognized.
        let(:call_element) { ripper }

        it 'detects constant', :aggregate_failures do
          expect(method_call.method_name).to eq(:hello)
          expect(method_call.arguments).to be_empty
        end
      end

      context 'when the receiver is an integer' do
        let(:code) { '1.hello()' }

        # This is where the :call token will be recognized.
        let(:call_element) { ripper }

        it 'detects integer', :aggregate_failures do
          expect(method_call.method_name).to eq(:hello)
          expect(method_call.arguments).to be_empty
        end
      end

      context 'when the receiver is a string' do
        let(:code) { "'hello'.hello()" }

        let(:call_element) { ripper }

        it 'detects string', :aggregate_failures do
          expect(method_call.method_name).to eq(:hello)
          expect(method_call.arguments).to be_empty
        end
      end

      context 'when the receiver is a variable' do
        let(:code) do
          "number_one = 1\n" \
            'number_one.hello()'
        end

        let(:call_element) { ripper[2] }

        it 'detects variable', :aggregate_failures do
          expect(method_call.method_name).to eq(:hello)
          expect(method_call.arguments).to be_empty
          expect(method_call.receiver).to be_a(Fastererer::VariableReference)
          expect(method_call.receiver.name).to eq(:number_one)
        end
      end

      context 'when the receiver is a method call' do
        let(:code) { '1.hi(2).hello()' }

        let(:call_element) { ripper }

        it 'detects method', :aggregate_failures do
          expect(method_call.method_name).to eq(:hello)
          expect(method_call.receiver).to be_a(described_class)
          expect(method_call.receiver.name).to eq(:hi)
          expect(method_call.arguments).to be_empty
        end
      end
      # rubocop:enable RSpec/NestedGroups
    end

    context 'without arguments, without block, called without parentheses' do
      # rubocop:disable RSpec/NestedGroups
      context 'when the receiver is a constant' do
        let(:code) { 'User.hello' }

        let(:call_element) { ripper }

        it 'detects constant', :aggregate_failures do
          expect(method_call.method_name).to eq(:hello)
          expect(method_call.arguments).to be_empty
        end
      end

      context 'when the receiver is an integer' do
        let(:code) { '1.hello' }

        # This is where the :call token will be recognized.
        let(:call_element) { ripper }

        it 'detects integer', :aggregate_failures do
          expect(method_call.method_name).to eq(:hello)
          expect(method_call.arguments).to be_empty
        end
      end

      context 'when the receiver is a string' do
        let(:code) { "'hello'.hello" }

        let(:call_element) { ripper }

        it 'detects string', :aggregate_failures do
          expect(method_call.method_name).to eq(:hello)
          expect(method_call.arguments).to be_empty
        end
      end

      context 'when the receiver is a variable' do
        let(:code) do
          "number_one = 1\n" \
            'number_one.hello'
        end

        let(:call_element) { ripper[2] }

        it 'detects variable', :aggregate_failures do
          expect(method_call.method_name).to eq(:hello)
          expect(method_call.arguments).to be_empty
          expect(method_call.receiver).to be_a(Fastererer::VariableReference)
          expect(method_call.receiver.name).to eq(:number_one)
        end
      end

      context 'when the receiver is a method call' do
        let(:code) { '1.hi(2).hello' }

        let(:call_element) { ripper }

        it 'detects method', :aggregate_failures do
          expect(method_call.method_name).to eq(:hello)
          expect(method_call.receiver).to be_a(described_class)
          expect(method_call.receiver.name).to eq(:hi)
          expect(method_call.arguments).to be_empty
        end
      end
      # rubocop:enable RSpec/NestedGroups
    end

    context 'with a "do end" block' do
      # rubocop:disable RSpec/NestedGroups
      context 'with no arguments and without a block parameter' do
        let(:code) do
          <<-CODE
            number_one.fetch do
              number_two = 2
              number_three = 3
            end
          CODE
        end

        let(:call_element) { ripper }

        it 'detects block', :aggregate_failures do
          expect(method_call.method_name).to eq(:fetch)
          expect(method_call.arguments).to be_empty
          expect(method_call).to be_block
          expect(method_call.block_argument_names).to be_empty
          expect(method_call.receiver).to be_a(described_class)
        end
      end

      context 'with no arguments and one block parameter' do
        let(:code) do
          <<-CODE
            number_one.fetch do |el|
              number_two = 2
              number_three = 3
            end
          CODE
        end

        let(:call_element) { ripper }

        it 'detects block', :aggregate_failures do
          expect(method_call.method_name).to eq(:fetch)
          expect(method_call.arguments).to be_empty
          expect(method_call).to be_block
          expect(method_call.block_argument_names).to contain_exactly(:el)
          expect(method_call.receiver).to be_a(described_class)
        end
      end

      context 'with no arguments and multiple block parameters' do
        let(:code) do
          <<-CODE
            number_one.fetch do |el, tip|
              number_two = 2
              number_three = 3
            end
          CODE
        end

        let(:call_element) { ripper }

        it 'detects block', :aggregate_failures do
          expect(method_call.method_name).to eq(:fetch)
          expect(method_call.arguments).to be_empty
          expect(method_call).to be_block
          expect(method_call.block_argument_names).to eq(%i[el tip])
          expect(method_call.receiver).to be_a(described_class)
        end
      end

      context 'with one argument within parentheses' do
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

        it 'detects block', :aggregate_failures do
          expect(method_call.method_name).to eq(:fetch)
          expect(method_call.arguments.count).to be(1)
          expect(method_call).to be_block
          expect(method_call.receiver).to be_a(Fastererer::VariableReference)
        end
      end
      # rubocop:enable RSpec/NestedGroups
    end

    context 'with a curly block' do
      # rubocop:disable RSpec/NestedGroups
      context 'when written on one line' do
        let(:code) do
          <<-CODE
            number_one = 1
            number_one.fetch { |el| number_two = 2 }
          CODE
        end

        let(:call_element) { ripper[2] }

        it 'detects block', :aggregate_failures do
          expect(method_call.method_name).to eq(:fetch)
          expect(method_call.arguments).to be_empty
          expect(method_call).to be_block
          expect(method_call.receiver).to be_a(Fastererer::VariableReference)
        end
      end

      context 'when written across multiple lines' do
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

        it 'detects block', :aggregate_failures do
          expect(method_call.method_name).to eq(:fetch)
          expect(method_call.arguments).to be_empty
          expect(method_call).to be_block
          expect(method_call.receiver).to be_a(Fastererer::VariableReference)
        end
      end
      # rubocop:enable RSpec/NestedGroups
    end

    context 'with arguments, without block, called with parentheses' do
      # rubocop:disable RSpec/NestedGroups
      context 'with one argument' do
        let(:code) { '{}.fetch(:writing)' }

        let(:call_element) { ripper }

        it 'detects argument', :aggregate_failures do
          expect(method_call.method_name).to eq(:fetch)
          expect(method_call.arguments.count).to eq(1)
          expect(method_call.arguments.first.type).to eq(:lit)
        end
      end
      # rubocop:enable RSpec/NestedGroups
    end

    context 'with arguments, without block, called without parentheses' do
      # rubocop:disable RSpec/NestedGroups
      context 'with two arguments' do
        let(:code) { '{}.fetch :writing, :listening' }

        let(:call_element) { ripper }

        it 'detects argument', :aggregate_failures do
          expect(method_call.method_name).to eq(:fetch)
          expect(method_call.arguments.count).to eq(2)
          expect(method_call.arguments[0].type).to eq(:lit)
          expect(method_call.arguments[1].type).to eq(:lit)
        end
      end
      # rubocop:enable RSpec/NestedGroups
    end
  end

  context 'with an argument and a block' do
    let(:code) do
      <<-CODE
        number_one = 1
        number_one.fetch(:writing) { [*1..100] }
      CODE
    end

    let(:call_element) { ripper[2] }

    it 'detects argument and a block', :aggregate_failures do
      expect(method_call.method_name).to eq(:fetch)
      expect(method_call.arguments.count).to eq(1)
      expect(method_call.arguments.first.type).to eq(:lit)
      expect(method_call).to be_block
      expect(method_call.receiver).to be_a(Fastererer::VariableReference)
    end
  end

  context 'without an explicit receiver' do
    let(:code) { 'fetch(:writing, :listening)' }

    let(:call_element) { ripper }

    it 'detects two arguments', :aggregate_failures do
      expect(method_call.method_name).to eq(:fetch)
      expect(method_call.arguments.count).to eq(2)
      expect(method_call.arguments[0].type).to eq(:lit)
      expect(method_call.arguments[1].type).to eq(:lit)
      expect(method_call.receiver).to be_nil
    end
  end

  context 'without an explicit receiver and without brackets' do
    let(:code) { 'fetch :writing, :listening' }

    let(:call_element) { ripper }

    it 'detects two arguments', :aggregate_failures do
      expect(method_call.method_name).to eq(:fetch)
      expect(method_call.arguments.count).to eq(2)
      expect(method_call.arguments[0].type).to eq(:lit)
      expect(method_call.arguments[1].type).to eq(:lit)
      expect(method_call.receiver).to be_nil
    end
  end

  context 'without an explicit receiver, without brackets, and with "do end"' do
    let(:code) do
      <<-CODE
        "fetch :writing do\n"\
        "end"
      CODE
    end

    let(:call_element) { ripper.drop(1).first.first }

    it 'detects argument and a block', skip: 'pending parser support' do
      # expect(method_call.method_name).to eq('fetch')
      # expect(method_call.arguments.count).to eq(2)
      # expect(method_call.arguments[0].type).to eq(:symbol_literal)
      # expect(method_call.arguments[1].type).to eq(:symbol_literal)
      # expect(method_call.receiver).to be_nil
    end
  end

  context 'with two arguments' do
    let(:code) do
      "number_one = 1\n" \
        'number_one.fetch(:writing, :zumba)'
    end

    let(:call_element) { ripper[2] }

    it 'detects arguments', :aggregate_failures do
      expect(method_call.method_name).to eq(:fetch)
      expect(method_call.arguments.count).to eq(2)
      expect(method_call.arguments[0].type).to eq(:lit)
      expect(method_call.arguments[1].type).to eq(:lit)
      expect(method_call.receiver).to be_a(Fastererer::VariableReference)
    end
  end

  context 'with a regex argument' do
    let(:code) { '{}.fetch(/.*/)' }

    let(:call_element) { ripper }

    it 'detects regex argument', :aggregate_failures do
      expect(method_call.method_name).to eq(:fetch)
      expect(method_call.arguments.count).to eq(1)
      expect(method_call.arguments[0].type).to eq(:lit)
      expect(method_call.arguments[0].value).to be_a(Regexp)
    end
  end

  context 'with an integer argument' do
    let(:code) { '[].flatten(1)' }

    let(:call_element) { ripper }

    it 'detects regex argument', :aggregate_failures do
      expect(method_call.method_name).to eq(:flatten)
      expect(method_call.arguments.count).to eq(1)
      expect(method_call.arguments[0].type).to eq(:lit)
      expect(method_call.arguments[0].value).to eq(1)
    end
  end

  context 'with a symbol-to-proc argument' do
    let(:code) { '[].select(&:zero?)' }

    let(:call_element) { ripper }

    it 'detects block pass argument', :aggregate_failures do
      expect(method_call.method_name).to eq(:select)
      expect(method_call.arguments.count).to eq(1)
      expect(method_call.arguments[0].type).to eq(:block_pass)
      expect(method_call).to be_block
    end
  end

  context 'with an equals operator' do
    let(:code) { 'method_call_with_equals.rb' }

    let(:call_element) { ripper.drop(1).first.first[1] }

    it 'recognizes receiver', skip: 'pending parser support' do
      # expect(method_call.method_name).to eq('hello')
      # expect(method_call.receiver).to be_a(Fastererer::MethodCall)
      # expect(method_call.receiver.name).to eq('hi')
    end
  end

  describe '#lambda_literal?' do
    context 'with a lambda literal without arguments' do
      let(:code) { '-> {}' }

      let(:call_element) { ripper }

      it 'is true' do
        expect(method_call).to be_lambda_literal
      end
    end

    context 'with a lambda literal with an argument' do
      let(:code) { '->(_) {}' }

      let(:call_element) { ripper }

      it 'is true' do
        expect(method_call).to be_lambda_literal
      end
    end

    context 'with the lambda method' do
      let(:code) { 'lambda {}' }

      let(:call_element) { ripper }

      it 'is false' do
        expect(method_call).not_to be_lambda_literal
      end
    end
  end
end
