# frozen_string_literal: true

require 'yaml'

module Fastererer
  class ConfigError < StandardError; end

  # Reads one configuration file and normalizes it into the shape the merge relies on. Used for
  # both the shipped defaults and the project file, so a hand-written config is validated too.
  class ConfigLoader
    SPEEDUPS_KEY      = 'speedups'
    EXCLUDE_PATHS_KEY = 'exclude_paths'
    NEW_SPEEDUPS_KEY  = 'new_speedups'

    def self.load(path)
      new(path).load
    end

    def initialize(path)
      @path = path
    end

    def load
      normalize(read)
    end

    private

    attr_reader :path

    def read
      loaded = YAML.safe_load_file(path)
      return {} unless loaded
      return loaded if loaded.is_a?(Hash)

      raise ConfigError, "#{path} must be a YAML mapping, not #{loaded.class}"
    rescue Errno::ENOENT
      raise ConfigError, "Fastererer configuration not found at #{path}"
    rescue Psych::SyntaxError => e
      raise ConfigError, "#{path} is not valid YAML: #{e.message}"
    rescue Psych::DisallowedClass => e
      raise ConfigError, "#{path} uses a YAML type fastererer does not allow: #{e.message}"
    end

    # A key present with no value inherits the default, so nil sections and nil entries both drop
    def normalize(loaded)
      normalized = {
        SPEEDUPS_KEY => fetch_hash(loaded, SPEEDUPS_KEY).compact,
        EXCLUDE_PATHS_KEY => fetch_array(loaded, EXCLUDE_PATHS_KEY).compact
      }
      mode = loaded[NEW_SPEEDUPS_KEY]
      mode.nil? ? normalized : normalized.merge(NEW_SPEEDUPS_KEY => mode)
    end

    def fetch_hash(loaded, key)
      fetch_typed(loaded, key, Hash, 'a mapping') || {}
    end

    def fetch_array(loaded, key)
      fetch_typed(loaded, key, Array, 'a list') || []
    end

    def fetch_typed(loaded, key, type, shape)
      value = loaded[key]
      return if value.nil?
      return value if value.is_a?(type)

      raise ConfigError, "#{path}: #{key} must be #{shape}, not #{value.class}"
    end
  end
end
