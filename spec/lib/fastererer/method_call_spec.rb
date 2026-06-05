# frozen_string_literal: true

require 'spec_helper'

describe Fastererer::MethodCall do
  include ParserHelpers

  let(:parsed) { Fastererer::Parser.parse(code) }
  let(:first_statement) { parsed.statements.body.first }
  let(:second_statement) { parsed.statements.body[1] }
  let(:method_call) { described_class.build(call_element) }

  def build_method_call(source)
    described_class.build(parse_first_statement(source))
  end

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

  context 'with an unmapped receiver node type' do
    let(:code) { '@items.map { |x| x }' }
    let(:call_element) { first_statement }

    it 'builds no recognized receiver', :aggregate_failures do
      expect(method_call.method_name).to eq(:map)
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

    it 'detects an argument and a block', :aggregate_failures do
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

  context 'without an explicit receiver, without brackets, and with a "do end" block' do
    let(:code) { "fetch :writing do\nend" }
    let(:call_element) { first_statement }

    it 'detects an argument and a block', :aggregate_failures do
      expect(method_call.method_name).to eq(:fetch)
      expect(method_call.arguments.count).to eq(1)
      expect(method_call.arguments.first.element).to be_a(Prism::SymbolNode)
      expect(method_call).to be_block
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

    it 'detects a regex argument', :aggregate_failures do
      expect(method_call.method_name).to eq(:fetch)
      expect(method_call.arguments.count).to eq(1)
      expect(method_call.arguments[0].element).to be_a(Prism::RegularExpressionNode)
    end
  end

  context 'with an integer argument' do
    let(:code) { '[].flatten(1)' }
    let(:call_element) { first_statement }

    it 'detects an integer argument', :aggregate_failures do
      expect(method_call.method_name).to eq(:flatten)
      expect(method_call.arguments.count).to eq(1)
      expect(method_call.arguments[0].element).to be_a(Prism::IntegerNode)
      expect(method_call.arguments[0].value).to eq(1)
    end
  end

  context 'with a symbol-to-proc argument' do
    let(:code) { '[].select(&:zero?)' }
    let(:call_element) { first_statement }

    it 'detects a block pass argument', :aggregate_failures do
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

  context 'with a namespaced constant receiver' do
    let(:code) { 'Foo::Bar.hello' }
    let(:call_element) { first_statement }

    it 'detects a namespaced constant receiver', :aggregate_failures do
      expect(method_call.method_name).to eq(:hello)
      expect(method_call.receiver).to be_a(Fastererer::VariableReference)
      expect(method_call.receiver.name).to eq(:Bar)
    end
  end

  describe '#block_argument_names' do
    it 'includes a required positional param' do
      expect(build_method_call('arr.map { |x| x.foo }').block_argument_names).to eq([:x])
    end

    it 'includes an optional positional param' do
      expect(build_method_call('arr.map { |x = 1| x.foo }').block_argument_names).to eq([:x])
    end

    it 'excludes a splat param so the count is not one' do
      expect(build_method_call('arr.map { |*x| x.foo }').block_argument_names).to eq([])
    end

    it 'includes only positional params, excluding keywords' do
      expect(build_method_call('arr.each { |a, b:| a }').block_argument_names).to eq([:a])
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

  describe 'LambdaCall' do
    let(:method_call) { described_class.build(parse_first_statement('->(x) { x.foo }')) }

    it 'builds a LambdaCall that reports as a lambda', :aggregate_failures do
      expect(method_call).to be_a(Fastererer::LambdaCall)
      expect(method_call).to be_lambda_literal
      expect(method_call).to be_block
      expect(method_call.method_name).to eq(:lambda)
    end

    it 'exposes inert call attributes', :aggregate_failures do
      expect(method_call.receiver).to be_nil
      expect(method_call.arguments).to be_empty
      expect(method_call.block_body).to be_nil
      expect(method_call.block_argument_names).to be_empty
    end
  end

  describe 'receiver through parenthesized expression' do
    context 'with a single expression in parentheses' do
      let(:code) { "arr = [1]\n(arr).map { |x| x }" }
      let(:call_element) { second_statement }

      it 'unwraps parentheses to find the receiver', :aggregate_failures do
        expect(method_call.method_name).to eq(:map)
        expect(method_call.receiver).to be_a(Fastererer::VariableReference)
        expect(method_call.receiver.name).to eq(:arr)
      end
    end

    context 'with multi-statement parentheses' do
      let(:code) { '(1; 2).to_s' }
      let(:call_element) { first_statement }

      it 'does not unwrap multi-statement parentheses', :aggregate_failures do
        expect(method_call.method_name).to eq(:to_s)
        expect(method_call.receiver).to be_nil
      end
    end

    context 'with a method call in parentheses' do
      let(:code) { '(1.to_s).length' }
      let(:call_element) { first_statement }

      it 'unwraps to the inner method call', :aggregate_failures do
        expect(method_call.method_name).to eq(:length)
        expect(method_call.receiver).to be_a(described_class)
        expect(method_call.receiver.name).to eq(:to_s)
      end
    end
  end

  describe 'Argument#type' do
    subject { method_call.arguments.first.type }

    let(:method_call) { build_method_call(code) }

    context 'with a symbol argument' do
      let(:code) { '{}.fetch(:key)' }

      it { is_expected.to eq(:symbol) }
    end

    context 'with a string argument' do
      let(:code) { '{}.fetch("key")' }

      it { is_expected.to eq(:string) }
    end

    context 'with an integer argument' do
      let(:code) { '[].flatten(1)' }

      it { is_expected.to eq(:integer) }
    end

    context 'with a float argument' do
      let(:code) { 'foo(1.5)' }

      it { is_expected.to eq(:float) }
    end

    context 'with a regexp argument' do
      let(:code) { '{}.fetch(/.*/) ' }

      it { is_expected.to eq(:regexp) }
    end

    context 'with a hash argument' do
      let(:code) { 'foo(a: 1)' }

      it { is_expected.to eq(:hash) }
    end

    context 'with a nil argument' do
      let(:code) { 'foo(nil)' }

      it { is_expected.to eq(:nil) }
    end

    context 'with an unmapped node type' do
      let(:code) { 'foo([1, 2])' }

      it { is_expected.to eq(:unknown) }
    end

    context 'with a boolean argument' do
      let(:code) { 'foo(true)' }

      it { is_expected.to eq(:boolean) }
    end

    context 'with a method call argument' do
      let(:code) { 'foo(bar)' }

      it { is_expected.to eq(:method_call) }
    end

    context 'with a local variable argument' do
      let(:code) { "value = 1\nfoo(value)" }
      let(:method_call) do
        described_class.build(Fastererer::Parser.parse(code).statements.body.last)
      end

      it { is_expected.to eq(:variable) }
    end
  end

  describe 'Argument#value' do
    subject { method_call.arguments.first.value }

    let(:method_call) { build_method_call(code) }

    context 'with a string argument' do
      let(:code) { '{}.fetch("hello")' }

      it { is_expected.to eq('hello') }
    end

    context 'with a symbol argument' do
      let(:code) { '{}.fetch(:key)' }

      it { is_expected.to eq(:key) }
    end

    context 'with an integer argument' do
      let(:code) { '[].flatten(1)' }

      it { is_expected.to eq(1) }
    end

    context 'with a float argument' do
      let(:code) { 'foo(2.5)' }

      it { is_expected.to eq(2.5) }
    end

    context 'with a boolean argument' do
      let(:code) { 'foo(true)' }

      it { is_expected.to be_nil }
    end

    context 'without a literal value' do
      let(:code) { 'foo([1, 2])' }

      it { is_expected.to be_nil }
    end
  end

  describe 'Primitive' do
    let(:call_element) { first_statement }

    context 'with an array receiver' do
      let(:code) { '[1, 2].map { |x| x }' }

      it 'detects array', :aggregate_failures do
        expect(method_call.receiver).to be_a(Fastererer::Primitive)
        expect(method_call.receiver).to be_array
        expect(method_call.receiver).not_to be_range
      end
    end

    context 'with a range receiver' do
      let(:code) { '(1..10).map { |x| x }' }

      it 'detects range', :aggregate_failures do
        expect(method_call.receiver).to be_a(Fastererer::Primitive)
        expect(method_call.receiver).to be_range
        expect(method_call.receiver).not_to be_array
      end
    end
  end
end
