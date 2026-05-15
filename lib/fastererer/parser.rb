# frozen_string_literal: true

require 'prism'

module Fastererer
  # Thin wrapper around Prism.parse to provide a stable internal API
  # and a single seam for testing or future parser changes.
  class Parser
    def self.parse(ruby_code)
      Prism.parse(ruby_code)
    end
  end
end
