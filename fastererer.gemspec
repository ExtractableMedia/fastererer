# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'fastererer/version'

Gem::Specification.new do |spec|
  spec.name          = 'fastererer'
  spec.version       = Fastererer::VERSION
  spec.authors       = ['Matt Menefee', 'Damir Svrtan']
  spec.email         = ['matt.menefee@extractablemedia.com', 'damir.svrtan@gmail.com']
  spec.summary       = 'Run Ruby more than fast. Fastererer'
  spec.description   = 'Use Fastererer to check various places in your code that could be faster. ' \
                       'A fork of fasterer (https://github.com/DamirSvrtan/fasterer) with Ruby 4.0 ' \
                       'support and native Prism parsing.'
  spec.homepage      = 'https://github.com/ExtractableMedia/fastererer'
  spec.license       = 'MIT'

  spec.metadata = {
    'source_code_uri' => 'https://github.com/ExtractableMedia/fastererer',
    'bug_tracker_uri' => 'https://github.com/ExtractableMedia/fastererer/issues',
    'changelog_uri'   => 'https://github.com/ExtractableMedia/fastererer/blob/main/CHANGELOG.md'
  }

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ['lib']

  spec.required_ruby_version = '>= 3.3'

  spec.add_dependency 'ruby_parser', '>= 3.22.0'

  spec.add_development_dependency 'bundler', '>= 1.6'
  spec.add_development_dependency 'pry',     '~> 0.10'
  spec.add_development_dependency 'rake',    '>= 12.3.3'
  spec.add_development_dependency 'rspec',   '~> 3.2'
  spec.add_development_dependency 'simplecov', '~> 0.9'
end
