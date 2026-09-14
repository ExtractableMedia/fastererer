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
    FORMAT_HELP = "Output format: #{Formatters::FORMATS.keys.join(', ')} " \
                  '(text is the default)'.freeze
    private_constant :FORMAT_HELP

    def self.execute(out: $stdout, err: $stderr)
      options = parse_options(ARGV.dup)
      formatter = Formatters.fetch(options[:format] || 'text').new(out:, err:)
    rescue UnknownFormatError, OptionParser::ParseError => e
      err.puts(e.message)
      exit USAGE_ERROR_STATUS
    else
      Painter.disable! if options[:no_color]
      file_traverser = FileTraverser.new(options[:path], formatter:)
      file_traverser.traverse
      exit_with_status_for(file_traverser)
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
        opts.on('-f', '--format FORMAT', FORMAT_HELP) do |format|
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
