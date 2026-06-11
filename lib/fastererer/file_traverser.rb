# frozen_string_literal: true

require 'pathname'
require 'English'

require_relative 'analyzer'
require_relative 'config'
require_relative 'finding'
require_relative 'report'
require_relative 'formatters/text_formatter'

module Fastererer
  class FileTraverser
    CONFIG_FILE_NAME  = Config::FILE_NAME
    SPEEDUPS_KEY      = Config::SPEEDUPS_KEY
    EXCLUDE_PATHS_KEY = Config::EXCLUDE_PATHS_KEY

    attr_reader :config, :parse_error_paths

    def initialize(path, formatter: Formatters::TextFormatter.new)
      @path = Pathname(path || '.')
      @parse_error_paths = []
      @config = Config.new
      @formatter = formatter
      @findings = []
    end

    def traverse
      @formatter.render(build_report)
    end

    def config_file
      config.file
    end

    def offenses_found?
      findings.any?
    end

    def scannable_files
      all_files - ignored_files
    end

    private

    attr_reader :formatter, :findings

    def build_report
      collect if @path.exist?

      Report.new(
        findings: findings,
        files_inspected_count: scannable_files.count,
        offenses_detected_count: findings.count,
        unparsable_files: parse_error_paths,
        missing_path: (@path.to_s unless @path.exist?)
      )
    end

    def collect
      scannable_files.each { |ruby_file| scan_file(ruby_file) }
    end

    def scan_file(path)
      analyzer = Analyzer.new(path)
      analyzer.scan
    rescue Fastererer::ParseError, SystemCallError, SystemStackError, EncodingError => e
      parse_error_paths.push(ErrorData.new(path, e.class, e.message).to_s)
    else
      collect_findings(analyzer)
    end

    def collect_findings(analyzer)
      reported_offenses(analyzer).each do |offense|
        findings.push(Finding.from(offense, analyzer.file_path))
      end
    end

    def reported_offenses(analyzer)
      analyzer.errors
              .group_by(&:name)
              .except(*ignored_speedups)
              .values
              .flatten
    end

    def all_files
      if @path.directory?
        Dir[File.join(@path, '**', '*.rb')].map do |ruby_file_path|
          Pathname(ruby_file_path).relative_path_from(root_dir).to_s
        end
      else
        [@path.to_s]
      end
    end

    def root_dir
      @root_dir ||= Pathname('.')
    end

    def ignored_speedups
      config.ignored_speedups
    end

    def ignored_files
      config.ignored_files
    end

    def nil_config_file
      config.nil_file
    end
  end

  ErrorData = Struct.new(:file_path, :error_class, :error_message) do
    def to_s
      "#{file_path} - #{error_class} - #{error_message}"
    end
  end
end
