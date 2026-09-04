# frozen_string_literal: true

require_relative 'config'

module Fastererer
  # Writes the starter .fastererer.yml that `fastererer init` installs. Every setting in it is
  # commented out bar one, so the file behaves exactly like having no file at all.
  class Installer
    STUB = <<~YAML
      # .fastererer.yml — fastererer configuration
      #
      # Everything here is optional. Anything you leave out keeps the value fastererer ships
      # with, so this file holds only your overrides. Run `fastererer --show-config` to see what
      # is in effect and where each value came from.
      #
      # Reference: https://github.com/ExtractableMedia/fastererer#configuration

      # How speedups added in a future release behave when you upgrade:
      #   enable  - active as soon as you upgrade (what `fastererer init` assumes you want)
      #   warn    - named on stderr, but report no offenses (the default with no config file)
      #   disable - stay off, silently
      new_speedups: enable

      # Turn individual speedups off. Only the keys you list change; every other speedup stays
      # on. `fastererer --show-config` lists them all.
      #
      # speedups:
      #   each_with_index_vs_while: false
      #   gsub_vs_tr: false

      # Extra paths to skip. These are ADDED to the shipped defaults (tmp/**/*.rb,
      # vendor/**/*.rb, node_modules/**/*.rb) — listing your own does not replace them.
      #
      # exclude_paths:
      #   - 'db/schema.rb'
    YAML

    def initialize(dir: Dir.pwd, out: $stdout, err: $stderr, force: false)
      @path = File.join(dir, Config::FILE_NAME)
      @out = out
      @err = err
      @force = force
    end

    def call
      if File.exist?(path) && !force
        err.puts("#{path} already exists. Pass --force to overwrite it.")
        return false
      end

      File.write(path, STUB)
      out.puts("Created #{path}")
      true
    end

    private

    attr_reader :path, :out, :err, :force
  end
end
