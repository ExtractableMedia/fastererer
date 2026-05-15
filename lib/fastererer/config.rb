# frozen_string_literal: true

require 'yaml'
require 'pathname'

module Fastererer
  class Config
    FILE_NAME         = '.fastererer.yml'
    SPEEDUPS_KEY      = 'speedups'
    EXCLUDE_PATHS_KEY = 'exclude_paths'

    def ignored_speedups
      @ignored_speedups ||=
        file[SPEEDUPS_KEY].select { |_, value| value == false }.keys.map(&:to_sym)
    end

    def ignored_files
      @ignored_files ||=
        file[EXCLUDE_PATHS_KEY].flat_map { |path| Dir[path] }
    end

    def file
      return @file if defined?(@file)

      @file = load_file
    end

    def file_location
      @file_location ||=
        Pathname(Dir.pwd)
        .enum_for(:ascend)
        .map { |dir| File.join(dir.to_s, FILE_NAME) }
        .find { |f| File.exist?(f) }
    end

    def nil_file
      { SPEEDUPS_KEY => {}, EXCLUDE_PATHS_KEY => [] }
    end

    private

    def load_file
      return nil_file if file_location.nil?

      # YAML.load_file returns false if the content is blank, so coerce to nil_file.
      loaded = YAML.load_file(file_location) || nil_file
      loaded.merge!(nil_file) { |_k, v1, v2| v1 || v2 }
    end
  end
end
