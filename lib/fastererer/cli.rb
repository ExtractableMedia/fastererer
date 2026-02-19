# frozen_string_literal: true

require_relative 'file_traverser'

module Fastererer
  class CLI
    def self.execute
      file_traverser = Fastererer::FileTraverser.new(ARGV[0])
      file_traverser.traverse
      abort if file_traverser.offenses_found?
    end
  end
end
