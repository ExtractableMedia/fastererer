# frozen_string_literal: true

require 'optparse'
require_relative 'file_traverser'
require_relative 'formatters'
require_relative 'painter'
require_relative 'version'

module Fastererer
  class CLI
    def self.execute(out: $stdout, err: $stderr)
      options = parse_options(ARGV.dup)
      Painter.disable! if options[:no_color]
      formatter = Formatters.fetch(options[:format] || 'text').new(out: out, err: err)
      file_traverser = Fastererer::FileTraverser.new(options[:path], formatter: formatter)
      file_traverser.traverse
      abort if file_traverser.offenses_found?
    rescue Fastererer::UnknownFormatError, OptionParser::ParseError => e
      err.puts(e.message)
      exit(1)
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
      puts Fastererer::VERSION
      exit
    end
  end
end
