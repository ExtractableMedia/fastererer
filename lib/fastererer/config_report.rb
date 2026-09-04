# frozen_string_literal: true

require_relative 'config'

module Fastererer
  # Renders the effective configuration for `--show-config`: every speedup with its state and
  # where that state came from. Deliberately not valid YAML -- output a reader could paste back
  # into .fastererer.yml would recreate the duplication that shipping defaults removes.
  class ConfigReport
    HELD_BACK = 'held back'
    KEY_WIDTH = 36
    STATE_WIDTH = 13

    def initialize(config:, out: $stdout)
      @config = config
      @out = out
    end

    def render
      out.puts(header)
      out.puts("\nSpeedups")
      speedup_rows.each { |row| out.puts(row) }
      out.puts("\nExclude paths")
      exclude_rows.each { |row| out.puts(row) }
    end

    private

    attr_reader :config, :out

    def header
      ["Defaults:       #{DefaultConfig::PATH}",
       "Project config: #{config.file_location || 'none — using the shipped defaults only'}",
       "New speedups:   #{config.file[Config::NEW_SPEEDUPS_KEY]} (#{source_of_mode})"]
    end

    def source_of_mode
      project_key?(Config::NEW_SPEEDUPS_KEY) ? 'project' : 'default'
    end

    def speedup_rows
      config.file[Config::SPEEDUPS_KEY].keys.sort.map do |name|
        "  #{name.ljust(KEY_WIDTH)}#{state_of(name).ljust(STATE_WIDTH)}#{speedup_source(name)}"
      end
    end

    # Off because it is new and off because you said so are different problems, so they read
    # differently here
    def state_of(name)
      return HELD_BACK if held_back?(name)

      config.ignored_speedups.include?(name.to_sym) ? 'disabled' : 'enabled'
    end

    def held_back?(name)
      config.new_speedups_mode == :warn && config.pending_speedups.include?(name.to_sym)
    end

    def speedup_source(name)
      project_speedups.key?(name) ? 'project' : 'default'
    end

    def exclude_rows
      config.file[Config::EXCLUDE_PATHS_KEY].map do |path|
        "  #{path.ljust(KEY_WIDTH)}#{exclude_source(path)}"
      end
    end

    def exclude_source(path)
      default_excludes.include?(path) ? 'default' : 'project'
    end

    def project_key?(key)
      config.project_config.key?(key)
    end

    def project_speedups
      config.project_config.fetch(Config::SPEEDUPS_KEY, {})
    end

    def default_excludes
      config.default_config[Config::EXCLUDE_PATHS_KEY]
    end
  end
end
