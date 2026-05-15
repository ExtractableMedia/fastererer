# frozen_string_literal: true

require_relative 'lib/fastererer/version'

Gem::Specification.new do |spec|
  spec.name          = 'fastererer'
  spec.version       = Fastererer::VERSION
  spec.authors       = ['Matt Menefee', 'Damir Svrtan']
  spec.email         = ['matt.menefee@extractablemedia.com', 'damir.svrtan@gmail.com']
  spec.summary       = 'Run Ruby more than fast. Fastererer'
  spec.description   = 'Use Fastererer to check various places in your code that could be ' \
                       'faster. A fork of fasterer (https://github.com/DamirSvrtan/fasterer) ' \
                       'with Ruby 4.0 support and native Prism parsing.'
  spec.homepage      = 'https://github.com/ExtractableMedia/fastererer'
  spec.license       = 'MIT'

  spec.metadata = {
    'source_code_uri' => 'https://github.com/ExtractableMedia/fastererer',
    'bug_tracker_uri' => 'https://github.com/ExtractableMedia/fastererer/issues',
    'changelog_uri' => 'https://github.com/ExtractableMedia/fastererer/blob/main/CHANGELOG.md',
    'documentation_uri' => 'https://rubydoc.info/gems/fastererer',
    'rubygems_mfa_required' => 'true'
  }

  spec.files = Dir.chdir(__dir__) do
    `git ls-files -z`.split("\x0").reject do |f|
      (File.expand_path(f) == __FILE__) ||
        f.start_with?(*%w[bin/ spec/ Gemfile .git .rspec .rubocop])
    end
  end
  spec.bindir        = 'exe'
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  spec.required_ruby_version = '>= 3.3'

  spec.add_dependency 'ruby_parser', '>= 3.22.0'
end
