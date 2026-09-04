# frozen_string_literal: true

require 'pathname'

require_relative 'config_loader'
require_relative 'default_config'

module Fastererer
  class Config
    FILE_NAME         = '.fastererer.yml'
    SPEEDUPS_KEY      = ConfigLoader::SPEEDUPS_KEY
    EXCLUDE_PATHS_KEY = ConfigLoader::EXCLUDE_PATHS_KEY

    def ignored_speedups
      @ignored_speedups ||=
        file[SPEEDUPS_KEY].select { |_, value| value == false }.keys.map(&:to_sym)
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

    private

    def project_config
      return {} if file_location.nil?

      ConfigLoader.load(file_location)
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
