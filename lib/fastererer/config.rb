# frozen_string_literal: true

require 'pathname'

require_relative 'config_loader'
require_relative 'default_config'

module Fastererer
  class Config
    FILE_NAME         = '.fastererer.yml'
    SPEEDUPS_KEY      = ConfigLoader::SPEEDUPS_KEY
    EXCLUDE_PATHS_KEY = ConfigLoader::EXCLUDE_PATHS_KEY
    NEW_SPEEDUPS_KEY  = ConfigLoader::NEW_SPEEDUPS_KEY
    PENDING           = 'pending'

    # `pending` is accepted as a synonym for `warn`, for anyone arriving from RuboCop's NewCops
    MODES = { 'enable' => :enable, 'warn' => :warn, PENDING => :warn, 'disable' => :disable }.freeze

    def ignored_speedups
      @ignored_speedups ||=
        file[SPEEDUPS_KEY].reject { |_, value| enabled?(value) }.keys.map(&:to_sym)
    end

    def pending_speedups
      @pending_speedups ||=
        file[SPEEDUPS_KEY].select { |_, value| value == PENDING }.keys.map(&:to_sym)
    end

    def new_speedups_mode
      @new_speedups_mode ||= MODES.fetch(file[NEW_SPEEDUPS_KEY]) do |mode|
        raise ConfigError,
              "new_speedups must be one of #{MODES.keys.join(', ')}, not #{mode.inspect}"
      end
    end

    def ignored_files
      @ignored_files ||=
        file[EXCLUDE_PATHS_KEY].flat_map { |path| Dir[path] }
    end

    def file
      @file ||= default_config.merge(project_config) do |key, default_value, project_value|
        merge_value(key, default_value, project_value)
      end
    end

    def file_location
      @file_location ||=
        Pathname(Dir.pwd)
        .enum_for(:ascend)
        .map { |dir| File.join(dir.to_s, FILE_NAME) }
        .find { |f| File.exist?(f) }
    end

    def default_config
      @default_config ||= DefaultConfig.load
    end

    def project_config
      return {} if file_location.nil?

      @project_config ||= ConfigLoader.load(file_location)
    end

    private

    def enabled?(value)
      return new_speedups_mode == :enable if value == PENDING

      value != false
    end

    def merge_value(key, default_value, project_value)
      case key
      when SPEEDUPS_KEY      then default_value.merge(project_value)
      when EXCLUDE_PATHS_KEY then default_value | project_value
      else project_value
      end
    end
  end
end
