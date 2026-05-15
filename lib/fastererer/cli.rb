# frozen_string_literal: true

require 'optparse'
require_relative 'file_traverser'
require_relative 'painter'
require_relative 'version'

module Fastererer
  class CLI
    def self.execute
      options = parse_options(ARGV.dup)
      Painter.disable! if options[:no_color]
      file_traverser = Fastererer::FileTraverser.new(options[:path])
      file_traverser.traverse
      abort if file_traverser.offenses_found?
    end

    def self.parse_options(argv)
      options = {}
      options[:path] = build_parser(options).parse(argv).first
      options
    end

    def self.build_parser(options)
      OptionParser.new do |opts|
        opts.banner = 'Usage: fastererer [options] [path]'
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
