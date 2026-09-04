# frozen_string_literal: true

require 'optparse'
require_relative 'config_report'
require_relative 'file_traverser'
require_relative 'formatters'
require_relative 'installer'
require_relative 'painter'
require_relative 'version'

module Fastererer
  class UsageError < StandardError; end

  class CLI
    OFFENSES_FOUND_STATUS = 1
    USAGE_ERROR_STATUS = 2
    INIT_COMMAND = 'init'

    def self.execute(argv: ARGV, out: $stdout, err: $stderr)
      argv = argv.dup
      return install(argv, out, err) if argv.first == INIT_COMMAND

      reject_misplaced_init(argv)
      options = parse_options(argv)
      return ConfigReport.new(config: Config.new, out:).render if options[:show_config]

      scan(options, formatter_for(options, out, err), err)
    rescue UnknownFormatError, OptionParser::ParseError, ConfigError, UsageError => e
      err.puts(e.message)
      exit USAGE_ERROR_STATUS
    end

    # A path really named init stays reachable as ./init, so the subcommand can win here
    def self.reject_misplaced_init(argv)
      return unless argv.include?(INIT_COMMAND)

      raise UsageError,
            "'#{INIT_COMMAND}' must be the first argument. " \
            "To scan a path named #{INIT_COMMAND}, write ./#{INIT_COMMAND}"
    end

    def self.formatter_for(options, out, err)
      Formatters.fetch(options[:format] || 'text').new(out:, err:)
    end

    def self.install(argv, out, err)
      options = parse_init_options(argv.drop(1))
      exit USAGE_ERROR_STATUS unless Installer.new(out:, err:, force: options[:force]).call
    end

    def self.parse_init_options(argv)
      options = {}
      OptionParser.new do |opts|
        opts.banner = "Usage: fastererer #{INIT_COMMAND} [--force]"
        opts.on('--force', 'Overwrite an existing configuration file') { options[:force] = true }
        opts.on('-h', '--help', 'Show this help') { show_help_and_exit(opts) }
      end.parse(argv)
      options
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
        describe_usage(opts)
        add_output_options(opts, options)
        add_information_options(opts, options)
      end
    end

    def self.add_output_options(opts, options)
      opts.on('-f', '--format FORMAT', 'Output format: text (default), json, rdjsonl') do |format|
        options[:format] = format
      end
      opts.on('--no-color', 'Disable ANSI color in output') { options[:no_color] = true }
    end

    def self.add_information_options(opts, options)
      opts.on('--show-config', 'Print the effective configuration') do
        options[:show_config] = true
      end
      opts.on('-h', '--help', 'Show this help') { show_help_and_exit(opts) }
      opts.on('-v', '--version', 'Show version') { show_version_and_exit }
    end

    def self.describe_usage(opts)
      opts.banner = 'Usage: fastererer [options] [path]'
      opts.separator("\nCommands:")
      opts.separator("    #{INIT_COMMAND}#{' ' * 26}Write a starter .fastererer.yml")
      opts.separator("\nOptions:")
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
