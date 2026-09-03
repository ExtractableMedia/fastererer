# frozen_string_literal: true

SimpleCov.configure do
  skip '/spec/'
  skip '/vendor/'
  # The gemspec requires this before SimpleCov starts, so its lines can never register as covered
  skip 'lib/fastererer/version.rb'

  # Report on every lib file, so one the suite never loads cannot sit unnoticed outside the total
  cover 'lib/**/*.rb'
  enable_coverage :branch

  group 'Scanners', 'lib/fastererer/scanners'

  coverage :line do
    minimum 96

    # The scanners are the rule logic and are fully line covered; hold new ones to that
    minimum_per_group 100, only: 'Scanners'
  end

  # Branch coverage runs well below line coverage, hence the lower floor
  coverage :branch do
    minimum 85
  end
end
