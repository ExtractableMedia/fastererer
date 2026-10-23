# frozen_string_literal: true

require 'optparse'
require_relative 'file_traverser'
require_relative 'formatters'
require_relative 'painter'
require_relative 'version'

module Fastererer
  class CLI
    OFFENSES_FOUND_STATUS = 1
    USAGE_ERROR_STATUS = 2

    def self.execute(out: $stdout, err: $stderr)
      options = parse_options(ARGV.dup)
      formatter = Formatters.fetch(options[:format] || 'text').new(out:, err:)
      scan(options, formatter, err)
    rescue UnknownFormatError, OptionParser::ParseError, ConfigError => e
      err.puts(e.message)
      exit USAGE_ERROR_STATUS
    end

    # The config is read before the scan, so a broken one reports instead of half-scanning
    def self.scan(options, formatter, err)
      Painter.disable! if options[:no_color]
      file_traverser = FileTraverser.new(options[:path], formatter:)
      report_held_back_speedups(file_traverser.config, err)
      file_traverser.traverse
      exit_with_status_for(file_traverser)
    end

    # Held back on stderr, never stdout, so a machine format stays parseable
    def self.report_held_back_speedups(config, err)
      return unless config.new_speedups_mode == :warn

      held_back = config.pending_speedups
      err.puts(held_back_notice(held_back)) unless held_back.empty?
    end

    def self.held_back_notice(held_back)
      subject = held_back.one? ? 'speedup is' : 'speedups are'
      ["fastererer: #{held_back.count} new #{subject} held back: #{held_back.join(', ')}.",
       'Set new_speedups to `enable` to turn new speedups on, or list them under `speedups:` ' \
       'to decide one at a time.']
    end

    def self.exit_with_status_for(file_traverser)
      exit USAGE_ERROR_STATUS if file_traverser.path_missing?
      exit OFFENSES_FOUND_STATUS if file_traverser.offenses_found?
    end

    def self.parse_options(argv)
      options = {}
      options[:path] = build_parser(options).parse(argv).first
      options
    end

    def self.build_parser(options)
      OptionParser.new do |opts|
        opts.banner = 'Usage: fastererer [options] [path]'
        opts.on('-f', '--format FORMAT', 'Output format: text (default), json, rdjsonl') do |format|
          options[:format] = format
        end
        opts.on('--no-color', 'Disable ANSI color in output') { options[:no_color] = true }
        opts.on('-h', '--help', 'Show this help') { show_help_and_exit(opts) }
        opts.on('-v', '--version', 'Show version') { show_version_and_exit }
      end
    end

    def self.show_help_and_exit(opts)
      puts opts
      exit
    end

    def self.show_version_and_exit
      puts VERSION
      exit
    end
  end
end
