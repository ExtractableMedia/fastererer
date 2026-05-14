# Contributing to fastererer

Thanks for your interest in improving `fastererer`. This document explains how to report issues
and submit code.

## Reporting Issues

Before opening a new issue:

1. Check the [existing issues][issues] to avoid duplicates.
2. Confirm the bug reproduces on the latest release.

When opening an issue, include:

- The output of `fastererer --version`
- Your Ruby version (`ruby --version`)
- A minimal reproduction — the smallest Ruby snippet that triggers the behavior
- The expected behavior and the actual behavior

## Pull Requests

1. Fork the repository and create a topic branch off `main`.
2. Run `bin/setup` to install dependencies (or `bundle install` directly).
3. Add tests that cover the change. Bug fixes should include a regression spec.
4. Run the test suite with `bundle exec rspec` and make sure it passes.
5. Update [CHANGELOG.md][changelog] under an unreleased heading describing the change.
6. Submit the PR with a clear description of what changed and why.

For non-trivial changes, consider opening an issue first to discuss the approach.

## Local Development

After cloning:

```bash
bin/setup            # installs dependencies
bin/console          # opens an IRB session with the gem loaded
bundle exec rspec    # runs the test suite
```

To try the executable against a Ruby file:

```bash
bundle exec exe/fastererer path/to/file.rb
```

## Code Style

- Follow the [Ruby Style Guide][ruby-style-guide].
- New Ruby files should start with `# frozen_string_literal: true`.
- Tests use RSpec — see existing specs in `spec/` for examples and conventions.

## Code of Conduct

By participating in this project, you agree to abide by its [Code of Conduct][code-of-conduct].

[changelog]: CHANGELOG.md
[code-of-conduct]: CODE_OF_CONDUCT.md
[issues]: https://github.com/ExtractableMedia/fastererer/issues
[ruby-style-guide]: https://rubystyle.guide
