# frozen_string_literal: true

module Fastererer
  class MethodDefinition
    # Exposed for testing purposes.
    attr_reader :element, :method_name, :block_argument_name, :body, :arguments

    alias name method_name

    def initialize(element)
      @element = element # Ripper element
      set_method_name
      set_body
      set_arguments
      set_block_argument_name
    end

    def block?
      !!@block_argument_name
    end

    def setter?
      name.to_s.end_with?('=')
    end

    private

    def arguments_element
      element[2].drop(1) || []
    end

    def set_method_name
      @method_name = @element[1]
    end

    def set_arguments
      @arguments = arguments_element.map do |argument_element|
        MethodDefinitionArgument.new(argument_element)
      end
    end

    def set_body
      @body = @element[3..]
    end

    def set_block_argument_name
      return unless last_argument_element.to_s.start_with?('&')

      @block_argument_name = last_argument_element.to_s.delete_prefix('&').to_sym
    end

    def last_argument_element
      arguments_element.last
    end
  end

  class MethodDefinitionArgument
    attr_reader :element, :name, :type

    def initialize(element)
      @element = element
      set_name
      set_argument_type
    end

    def regular_argument?
      @type == :regular_argument
    end

    def default_argument?
      @type == :default_argument
    end

    def keyword_argument?
      @type == :keyword_argument
    end

    private

    def set_name
      @name = element.is_a?(Symbol) ? element : element[1]
    end

    def set_argument_type
      @type = if element.is_a?(Symbol)
                :regular_argument
              elsif element.is_a?(Sexp) && element.sexp_type == :lasgn
                :default_argument
              elsif element.is_a?(Sexp) && element.sexp_type == :kwarg
                :keyword_argument
              end
    end
  end
end
