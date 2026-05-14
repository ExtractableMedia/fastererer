# frozen_string_literal: true

require 'bundler/gem_tasks'
require 'rspec/core/rake_task'
require 'rubocop/rake_task'

desc 'Run all RSpec tests'
RSpec::Core::RakeTask.new(:spec)

RuboCop::RakeTask.new

task default: %i[spec rubocop]
