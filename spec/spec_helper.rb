# frozen_string_literal: true

require 'bundler/setup'

require 'simplecov'
SimpleCov.start

require 'fastererer'
require 'fastererer/cli'

Dir["#{File.dirname(__FILE__)}/support/*.rb"].each { |f| require f }

def RSpec.root
  @root_path = Pathname.new(File.dirname(__FILE__))
end

RSpec.configure do |config|
  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end

  # Kernel#print goes straight through IO#write, so stubbing :print alone would not silence it
  config.before { allow($stdout).to receive_messages(puts: nil, write: nil) }
end
