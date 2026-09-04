# frozen_string_literal: true

require_relative 'config_loader'

module Fastererer
  # The defaults shipped with the gem. Deep-frozen because Hash#merge is shallow: an unfrozen
  # nested hash here would be reachable, and mutable, through every merged copy.
  module DefaultConfig
    PATH = File.expand_path('../../config/default.yml', __dir__)

    def self.load(path = PATH)
      deep_freeze(ConfigLoader.load(path))
    end

    def self.deep_freeze(value)
      case value
      when Hash  then value.each_value { |nested| deep_freeze(nested) }.freeze
      when Array then value.each { |nested| deep_freeze(nested) }.freeze
      else value.freeze
      end
    end
    private_class_method :deep_freeze
  end
end
