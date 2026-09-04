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

    def path_missing?
      return @path_missing if defined?(@path_missing)

      @path_missing = !@path.exist?
    end

    def scannable_files
      all_files - ignored_files
    end

    private

    attr_reader :findings

    def build_report
      scan_files

      Report.new(
        findings:,
        files_inspected_count: scannable_files.count,
        unparsable_files: parse_error_paths,
        missing_path: (@path.to_s if path_missing?)
      )
    end

    def scan_files
      scannable_files.each { |ruby_file| scan_file(ruby_file) }
    end

    def scan_file(path)
      analyzer = Analyzer.new(path)
      analyzer.scan
    rescue Fastererer::ParseError, SystemCallError, SystemStackError, EncodingError => e
      parse_error_paths.push(ErrorData.new(path, e.class, e.message))
    else
      collect_findings(analyzer)
    end

    def collect_findings(analyzer)
      reported_offenses(analyzer).each do |offense|
        findings.push(Finding.from(offense, analyzer.file_path))
      end
    end

    def reported_offenses(analyzer)
      ignored = ignored_speedups
      analyzer.errors.reject { |offense| ignored.include?(offense.name) }
    end

    def all_files
      return [] if path_missing?
      return [@path.to_s] unless @path.directory?

      # base: takes the directory literally; interpolating it would read [ ] { } * ? as pattern
      Dir.glob('**/*.rb', base: @path.to_s).map do |relative_path|
        Pathname(File.join(@path, relative_path)).cleanpath.to_s
      end
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
