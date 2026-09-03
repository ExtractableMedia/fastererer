# frozen_string_literal: true

# A run narrowed to some specs cannot reach the floors below, so they only apply to the whole suite
narrowing_flags = %w[-e --example -t --tag]
whole_suite = ARGV.none? { |arg| arg.start_with?('spec/') || narrowing_flags.include?(arg) }

SimpleCov.configure do
  skip '/spec/'
  skip '/vendor/'
  # The gemspec requires this before SimpleCov starts, so its lines can never register as covered
  skip 'lib/fastererer/version.rb'

  # Report on every lib file, so one the suite never loads cannot sit unnoticed outside the total
  cover 'lib/**/*.rb'
  enable_coverage :branch

  group 'Scanners', 'lib/fastererer/scanners'

  # Only the whole suite can reach these floors, so a narrowed run reports without failing
  if whole_suite
    coverage :line do
      minimum 100
    end

    coverage :branch do
      minimum 100
    end
  end
end
