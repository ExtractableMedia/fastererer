# frozen_string_literal: true

require 'spec_helper'

describe Fastererer::MethodCall do
  let(:parsed) { Fastererer::Parser.parse(code) }

  # Extract the first statement from parsed result
  let(:first_statement) { parsed.value.statements.body.first }

  # Extract the second statement (for multi-statement code)
  let(:second_statement) { parsed.value.statements.body[1] }

  let(:method_call) { described_class.new(call_element) }

  context 'with explicit receiver' do
    context 'without arguments, without block, called with parentheses' do
      # rubocop:disable RSpec/NestedGroups
      context 'when the receiver is a constant' do
        let(:code) { 'User.hello()' }
        let(:call_element) { first_statement }

        it 'detects constant', :aggregate_failures do
          expect(method_call.method_name).to eq(:hello)
          expect(method_call.arguments).to be_empty
          expect(method_call.receiver).to be_a(Fastererer::VariableReference)
          expect(method_call.receiver.name).to eq(:User)
        end
      end

      context 'when the receiver is an integer' do
        let(:code) { '1.hello()' }
        let(:call_element) { first_statement }

        it 'detects integer', :aggregate_failures do
          expect(method_call.method_name).to eq(:hello)
          expect(method_call.arguments).to be_empty
          expect(method_call.receiver).to be_a(Fastererer::Primitive)
        end
      end

      context 'when the receiver is a string' do
        let(:code) { "'hello'.hello()" }
        let(:call_element) { first_statement }

        it 'detects string', :aggregate_failures do
          expect(method_call.method_name).to eq(:hello)
          expect(method_call.arguments).to be_empty
          expect(method_call.receiver).to be_a(Fastererer::Primitive)
        end
      end

      context 'when the receiver is a variable' do
        let(:code) { "number_one = 1\nnumber_one.hello()" }
        let(:call_element) { second_statement }

        it 'detects variable', :aggregate_failures do
          expect(method_call.method_name).to eq(:hello)
          expect(method_call.arguments).to be_empty
          expect(method_call.receiver).to be_a(Fastererer::VariableReference)
          expect(method_call.receiver.name).to eq(:number_one)
        end
      end

      context 'when the receiver is a method call' do
        let(:code) { '1.hi(2).hello()' }
        let(:call_element) { first_statement }

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
        let(:call_element) { first_statement }

        it 'detects constant', :aggregate_failures do
          expect(method_call.method_name).to eq(:hello)
          expect(method_call.arguments).to be_empty
          expect(method_call.receiver).to be_a(Fastererer::VariableReference)
          expect(method_call.receiver.name).to eq(:User)
        end
      end

      context 'when the receiver is an integer' do
        let(:code) { '1.hello' }
        let(:call_element) { first_statement }

        it 'detects integer', :aggregate_failures do
          expect(method_call.method_name).to eq(:hello)
          expect(method_call.arguments).to be_empty
          expect(method_call.receiver).to be_a(Fastererer::Primitive)
        end
      end

      context 'when the receiver is a string' do
        let(:code) { "'hello'.hello" }
        let(:call_element) { first_statement }

        it 'detects string', :aggregate_failures do
          expect(method_call.method_name).to eq(:hello)
          expect(method_call.arguments).to be_empty
          expect(method_call.receiver).to be_a(Fastererer::Primitive)
        end
      end

      context 'when the receiver is a variable' do
        let(:code) { "number_one = 1\nnumber_one.hello" }
        let(:call_element) { second_statement }

        it 'detects variable', :aggregate_failures do
          expect(method_call.method_name).to eq(:hello)
          expect(method_call.arguments).to be_empty
          expect(method_call.receiver).to be_a(Fastererer::VariableReference)
          expect(method_call.receiver.name).to eq(:number_one)
        end
      end

      context 'when the receiver is a method call' do
        let(:code) { '1.hi(2).hello' }
        let(:call_element) { first_statement }

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
          <<~RUBY
            number_one.fetch do
              number_two = 2
              number_three = 3
            end
          RUBY
        end
        let(:call_element) { first_statement }

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
          <<~RUBY
            number_one.fetch do |el|
              number_two = 2
              number_three = 3
            end
          RUBY
        end
        let(:call_element) { first_statement }

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
          <<~RUBY
            number_one.fetch do |el, tip|
              number_two = 2
              number_three = 3
            end
          RUBY
        end
        let(:call_element) { first_statement }

        it 'detects block', :aggregate_failures do
          expect(method_call.method_name).to eq(:fetch)
          expect(method_call.arguments).to be_empty
          expect(method_call).to be_block
          expect(method_call.block_argument_names).to eq(%i[el tip])
          expect(method_call.receiver).to be_a(described_class)
        end
      end

      context 'with a destructured block parameter' do
        let(:code) do
          <<~RUBY
            pairs.each do |(a, b), c|
              do_something(a, b, c)
            end
          RUBY
        end
        let(:call_element) { first_statement }

        it 'represents the destructured parameter with nil' do
          expect(method_call.block_argument_names).to eq([nil, :c])
        end
      end

      context 'with one argument within parentheses' do
        let(:code) do
          <<~RUBY
            number_one = 1
            number_one.fetch(100) do |el|
              number_two = 2
              number_three = 3
            end
          RUBY
        end
        let(:call_element) { second_statement }

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
          <<~RUBY
            number_one = 1
            number_one.fetch { |el| number_two = 2 }
          RUBY
        end
        let(:call_element) { second_statement }

        it 'detects block', :aggregate_failures do
          expect(method_call.method_name).to eq(:fetch)
          expect(method_call.arguments).to be_empty
          expect(method_call).to be_block
          expect(method_call.receiver).to be_a(Fastererer::VariableReference)
        end
      end

      context 'when written across multiple lines' do
        let(:code) do
          <<~RUBY
            number_one = 1
            number_one.fetch { |el|
              number_two = 2
              number_three = 3
            }
          RUBY
        end
        let(:call_element) { second_statement }

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
        let(:call_element) { first_statement }

        it 'detects argument', :aggregate_failures do
          expect(method_call.method_name).to eq(:fetch)
          expect(method_call.arguments.count).to eq(1)
          expect(method_call.arguments.first.element).to be_a(Prism::SymbolNode)
        end
      end
      # rubocop:enable RSpec/NestedGroups
    end

    context 'with arguments, without block, called without parentheses' do
      # rubocop:disable RSpec/NestedGroups
      context 'with two arguments' do
        let(:code) { '{}.fetch :writing, :listening' }
        let(:call_element) { first_statement }

        it 'detects argument', :aggregate_failures do
          expect(method_call.method_name).to eq(:fetch)
          expect(method_call.arguments.count).to eq(2)
          expect(method_call.arguments[0].element).to be_a(Prism::SymbolNode)
          expect(method_call.arguments[1].element).to be_a(Prism::SymbolNode)
        end
      end
      # rubocop:enable RSpec/NestedGroups
    end
  end

  context 'with implicit receiver' do
    let(:code) { 'puts "hello"' }
    let(:call_element) { first_statement }

    it 'has nil receiver', :aggregate_failures do
      expect(method_call.method_name).to eq(:puts)
      expect(method_call.receiver).to be_nil
    end
  end

  context 'with an argument and a block' do
    let(:code) do
      <<~RUBY
        number_one = 1
        number_one.fetch(:writing) { [*1..100] }
      RUBY
    end
    let(:call_element) { second_statement }

    it 'detects argument and a block', :aggregate_failures do
      expect(method_call.method_name).to eq(:fetch)
      expect(method_call.arguments.count).to eq(1)
      expect(method_call.arguments.first.element).to be_a(Prism::SymbolNode)
      expect(method_call).to be_block
      expect(method_call.receiver).to be_a(Fastererer::VariableReference)
    end
  end

  context 'without an explicit receiver' do
    let(:code) { 'fetch(:writing, :listening)' }
    let(:call_element) { first_statement }

    it 'detects two arguments', :aggregate_failures do
      expect(method_call.method_name).to eq(:fetch)
      expect(method_call.arguments.count).to eq(2)
      expect(method_call.arguments[0].element).to be_a(Prism::SymbolNode)
      expect(method_call.arguments[1].element).to be_a(Prism::SymbolNode)
      expect(method_call.receiver).to be_nil
    end
  end

  context 'without an explicit receiver and without brackets' do
    let(:code) { 'fetch :writing, :listening' }
    let(:call_element) { first_statement }

    it 'detects two arguments', :aggregate_failures do
      expect(method_call.method_name).to eq(:fetch)
      expect(method_call.arguments.count).to eq(2)
      expect(method_call.arguments[0].element).to be_a(Prism::SymbolNode)
      expect(method_call.arguments[1].element).to be_a(Prism::SymbolNode)
      expect(method_call.receiver).to be_nil
    end
  end

  context 'with two arguments' do
    let(:code) { "number_one = 1\nnumber_one.fetch(:writing, :zumba)" }
    let(:call_element) { second_statement }

    it 'detects arguments', :aggregate_failures do
      expect(method_call.method_name).to eq(:fetch)
      expect(method_call.arguments.count).to eq(2)
      expect(method_call.arguments[0].element).to be_a(Prism::SymbolNode)
      expect(method_call.arguments[1].element).to be_a(Prism::SymbolNode)
      expect(method_call.receiver).to be_a(Fastererer::VariableReference)
    end
  end

  context 'with a regex argument' do
    let(:code) { '{}.fetch(/.*/)' }
    let(:call_element) { first_statement }

    it 'detects regex argument', :aggregate_failures do
      expect(method_call.method_name).to eq(:fetch)
      expect(method_call.arguments.count).to eq(1)
      expect(method_call.arguments[0].element).to be_a(Prism::RegularExpressionNode)
    end
  end

  context 'with an integer argument' do
    let(:code) { '[].flatten(1)' }
    let(:call_element) { first_statement }

    it 'detects integer argument', :aggregate_failures do
      expect(method_call.method_name).to eq(:flatten)
      expect(method_call.arguments.count).to eq(1)
      expect(method_call.arguments[0].element).to be_a(Prism::IntegerNode)
      expect(method_call.arguments[0].value).to eq(1)
    end
  end

  context 'with a symbol-to-proc argument' do
    let(:code) { '[].select(&:zero?)' }
    let(:call_element) { first_statement }

    it 'detects block pass argument', :aggregate_failures do
      expect(method_call.method_name).to eq(:select)
      expect(method_call.arguments).to be_empty
      expect(method_call).to be_block
    end
  end

  context 'with an equals operator' do
    let(:code) { "downcase() == 'hombre'" }
    let(:call_element) { first_statement }

    it 'recognizes receiver', :aggregate_failures do
      expect(method_call.method_name).to eq(:==)
      expect(method_call.receiver).to be_a(described_class)
      expect(method_call.receiver.name).to eq(:downcase)
    end
  end

  describe 'receiver through parenthesized expression' do
    describe 'single expression in parentheses' do
      let(:code) { "arr = [1]\n(arr).map { |x| x }" }
      let(:call_element) { second_statement }

      it 'unwraps parentheses to find the receiver', :aggregate_failures do
        expect(method_call.method_name).to eq(:map)
        expect(method_call.receiver).to be_a(Fastererer::VariableReference)
        expect(method_call.receiver.name).to eq(:arr)
      end
    end

    describe 'multi-statement parentheses (not unwrapped)' do
      let(:code) { '(1; 2).to_s' }
      let(:call_element) { first_statement }

      it 'does not unwrap multi-statement parentheses', :aggregate_failures do
        expect(method_call.method_name).to eq(:to_s)
        expect(method_call.receiver).to be_nil
      end
    end

    describe 'method call in parentheses' do
      let(:code) { '(1.to_s).length' }
      let(:call_element) { first_statement }

      it 'unwraps to the inner method call', :aggregate_failures do
        expect(method_call.method_name).to eq(:length)
        expect(method_call.receiver).to be_a(described_class)
        expect(method_call.receiver.name).to eq(:to_s)
      end
    end
  end

  describe '#lambda_literal?' do
    context 'with a lambda literal without arguments' do
      let(:code) { '-> {}' }
      let(:call_element) { first_statement }

      it 'is true' do
        expect(method_call).to be_lambda_literal
      end
    end

    context 'with a lambda literal with an argument' do
      let(:code) { '->(_) {}' }
      let(:call_element) { first_statement }

      it 'is true' do
        expect(method_call).to be_lambda_literal
      end
    end

    context 'with the lambda method' do
      let(:code) { 'lambda {}' }
      let(:call_element) { first_statement }

      it 'is false' do
        expect(method_call).not_to be_lambda_literal
      end
    end
  end

  describe 'Argument#type' do
    let(:method_call) { described_class.new(first_statement) }

    it 'returns :symbol for symbol arguments' do
      parsed = Fastererer::Parser.parse('{}.fetch(:key)')
      node = parsed.value.statements.body.first
      mc = described_class.new(node)
      expect(mc.arguments.first.type).to eq(:symbol)
    end

    it 'returns :string for string arguments' do
      parsed = Fastererer::Parser.parse('{}.fetch("key")')
      node = parsed.value.statements.body.first
      mc = described_class.new(node)
      expect(mc.arguments.first.type).to eq(:string)
    end

    it 'returns :integer for integer arguments' do
      parsed = Fastererer::Parser.parse('[].flatten(1)')
      node = parsed.value.statements.body.first
      mc = described_class.new(node)
      expect(mc.arguments.first.type).to eq(:integer)
    end

    it 'returns :float for float arguments' do
      parsed = Fastererer::Parser.parse('foo(1.5)')
      node = parsed.value.statements.body.first
      mc = described_class.new(node)
      expect(mc.arguments.first.type).to eq(:float)
    end

    it 'returns :regexp for regexp arguments' do
      parsed = Fastererer::Parser.parse('{}.fetch(/.*/) ')
      node = parsed.value.statements.body.first
      mc = described_class.new(node)
      expect(mc.arguments.first.type).to eq(:regexp)
    end

    it 'returns :hash for hash arguments' do
      parsed = Fastererer::Parser.parse('foo(a: 1)')
      node = parsed.value.statements.body.first
      mc = described_class.new(node)
      expect(mc.arguments.first.type).to eq(:hash)
    end

    it 'returns :unknown for unhandled node types' do
      parsed = Fastererer::Parser.parse('foo(nil)')
      node = parsed.value.statements.body.first
      mc = described_class.new(node)
      expect(mc.arguments.first.type).to eq(:unknown)
    end
  end

  describe 'Argument#value' do
    it 'returns string value for string arguments' do
      parsed = Fastererer::Parser.parse('{}.fetch("hello")')
      node = parsed.value.statements.body.first
      mc = described_class.new(node)
      expect(mc.arguments.first.value).to eq('hello')
    end

    it 'returns symbol value for symbol arguments' do
      parsed = Fastererer::Parser.parse('{}.fetch(:key)')
      node = parsed.value.statements.body.first
      mc = described_class.new(node)
      expect(mc.arguments.first.value).to eq(:key)
    end

    it 'returns float value for float arguments' do
      parsed = Fastererer::Parser.parse('foo(2.5)')
      node = parsed.value.statements.body.first
      mc = described_class.new(node)
      expect(mc.arguments.first.value).to eq(2.5)
    end

    it 'returns nil for unhandled node types' do
      parsed = Fastererer::Parser.parse('foo(nil)')
      node = parsed.value.statements.body.first
      mc = described_class.new(node)
      expect(mc.arguments.first.value).to be_nil
    end
  end

  describe 'ArgumentFactory' do
    it 'returns Argument for regular argument nodes', :aggregate_failures do
      parsed = Fastererer::Parser.parse('[].flatten(1)')
      node = parsed.value.statements.body.first
      mc = described_class.new(node)
      expect(mc.arguments.first).to be_a(Fastererer::Argument)
      expect(mc.arguments.first).not_to be_a(Fastererer::BlockArgument)
    end
  end

  describe 'BlockArgument' do
    it 'always returns :block_pass for type' do
      node = Prism.parse('foo(&block)').value.statements.body.first.block
      arg = Fastererer::BlockArgument.new(node)
      expect(arg.type).to eq(:block_pass)
    end
  end

  describe 'Primitive' do
    let(:call_element) { first_statement }

    describe 'array receiver' do
      let(:code) { '[1, 2].map { |x| x }' }

      it 'detects array', :aggregate_failures do
        expect(method_call.receiver).to be_a(Fastererer::Primitive)
        expect(method_call.receiver).to be_array
        expect(method_call.receiver).not_to be_range
      end
    end

    describe 'range receiver' do
      let(:code) { '(1..10).map { |x| x }' }

      it 'detects range', :aggregate_failures do
        expect(method_call.receiver).to be_a(Fastererer::Primitive)
        expect(method_call.receiver).to be_range
        expect(method_call.receiver).not_to be_array
      end
    end
  end

  describe 'namespaced constant receiver' do
    let(:code) { 'Foo::Bar.hello' }
    let(:call_element) { first_statement }

    it 'detects namespaced constant receiver', :aggregate_failures do
      expect(method_call.method_name).to eq(:hello)
      expect(method_call.receiver).to be_a(Fastererer::VariableReference)
      expect(method_call.receiver.name).to eq(:Bar)
    end
  end
end
