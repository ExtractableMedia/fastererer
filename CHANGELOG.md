# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog] and this project adheres to [Semantic Versioning].

Versions 0.11.0 and earlier were released as [`fasterer`](https://github.com/DamirSvrtan/fasterer), prior to the fork. From 0.12.0 onward, this is `fastererer`, maintained by ExtractableMedia.

## [Unreleased]

### Changed

- [#9]: Migrate from `ruby_parser` to Ruby's native Prism parser. Prism ships with Ruby itself,
  so this drops the `ruby_parser`, `sexp_processor`, and `racc` dependencies and keeps the
  analyzer in step with current and future Ruby syntax, including Ruby 4.0.

### Added

- [#9]: Detect speedups reached through a safe-navigation chain (e.g. `arr&.first`,
  `arr&.select { … }.first`), which the previous S-expression scanner skipped.
- [#9]: Detect speedups inside `rescue` bodies — getter-vs-`attr_reader`,
  setter-vs-`attr_writer`, and proc-call-vs-`yield` offenses are now scanned in rescue clauses.
- [#15]: Offense output now mirrors RuboCop's format with a `Performance/RuleName` rule name and a
  [fast-ruby](https://github.com/fastruby/fast-ruby) documentation link, e.g.
  `path:line: W: Performance/ForLoopVsEach: For loop is slower than using each. (url)`.

### Fixed

- [#9]: Block calls inside a nested scope (a singleton class or a nested method definition) are
  no longer misattributed to the enclosing method.
- [#9]: Unparseable source now raises a clear error instead of silently reporting no offenses.

## [0.12.0] - 2026-05-18

### Added

- [#2]: Explicit support for Ruby 4.0.
- [#42]: `NO_COLOR` env var and `--no-color` flag to suppress ANSI color output. Color also
  auto-disables when STDOUT isn't a TTY (piped output, CI logs, editor integrations).
- [#42]: `--help`/`-h` and `--version`/`-v` CLI flags.

### Changed

- [#1]: Rename the gem from `fasterer` to `fastererer`:
  - Config filename: `.fasterer.yml` → `.fastererer.yml`.
  - Executable: `fasterer` → `fastererer`.
  - Top-level module: `Fasterer` → `Fastererer`.

### Removed

- [#2]: Support for EOL Ruby versions (2.x, 3.0, 3.1, 3.2). Minimum required Ruby is now 3.3.

### Fixed

- `select_last_vs_reverse_detect` no longer reports a false positive when `.last` is called with
  arguments. `.last(n)` can return multiple elements, so `detect` (which only returns the first
  match) isn't an equivalent replacement. Mirrors the same fix for `select_first_vs_detect`
  shipped in 0.10.1.

## 0.11.0

- There have been multiple issues filed with the colorize gem, such as licencing, gem versions etc. Due to the easy implementation, fasterer will now leverage an internal implementation of this so we don't need to get issues tracked bc of colorize. There might be other issues that arise (perhaps somebody leveraging Windows might have issues), but that's okay, we'll solve it.

- There has been a [bug report #102](https://github.com/DamirSvrtan/fasterer/issues/102) that the Redis `#keys` method shouldn't trigger `Hash#each_key` recommendation. It's not possible to detect that what is the receiver of the keys method call, but the keys method called on the Hash doesn't accept arguments while the redis one does. So not an ideal solution, but should fix any issues for now.


## 0.10.1

- There has been a [bug report #99](https://github.com/DamirSvrtan/fasterer/issues/99) that the `select_first_vs_detect` reports false positives when first gets an argument passed in. If there is an argument passed in, the detect method is not suitable, since it always returns the first element matching (can't return multiple items).

## 0.10.0

- Due to issues while setting up builds with Github Actions, I have dropped Ruby 2.2
  support. It's EOL date was 2018-03-31, and I don't have the bandwidth to support
  deprecated Ruby versions. The only reason at this point why Ruby versions 2.3, 2.4
  and 2.5 are supported is because they still work with other dependencies, so it's
  no effort currently to support them. Once they become issues, they'll probably be
  dropped.
- Upgrade to ruby_parser 3.19.1 that fully supports Ruby 3.1

## 0.9.0

- Ruby 3 support! Merged in [#85](https://github.com/DamirSvrtan/fasterer/pull/85), a PR that relaxed Ruby version constraints and added a minor change to support Ruby 3.0. Thanks to [swiknaba](https://github.com/swiknaba).

## 0.8.3

- Merged in [#79](https://github.com/DamirSvrtan/fasterer/pull/79), a PR that makes sure the output is green when there are no failures.

## 0.8.2

- Fixes [#77](https://github.com/DamirSvrtan/fasterer/issues/77). An error occurs on the symbol to proc check when somebody invokes a method with no arguments on an array or range inside of the inspected block. Seems like a bug in the inspected code, but nevertheless it is a code path we need to support.

## 0.8.1

- Ignore lambda literals when checking symbol to proc. Thanks to [kiyot](https://github.com/kiyot) for his fix in PR [#74](https://github.com/DamirSvrtan/fasterer/pull/74).

## 0.8.0

- Dropped support for ruby versions below 2.2.0 and locks ruby_parser to be above or equal to 1.14.1. The new ruby_parser version 1.14.1 explicitly [requires ruby versions above 2.2.0](https://github.com/seattlerb/ruby_parser/issues/298#issuecomment-539795933), so this affects fasterer as well.

## 0.7.1

- Fix `check_symbol_to_proc` rule from crashing when there is no receiver [#67](https://github.com/DamirSvrtan/fasterer/pull/67)

## 0.7.0

- More inclusive `check_symbol_to_proc` rule - don't only look at #each but any method that could leverage the symbol to proc rule. Merged through [#41](https://github.com/DamirSvrtan/fasterer/pull/41)

## 0.6.0

- Enable placing the `.fasterer.yml` file not just in the current dir, but in any parent directory as well.

## 0.5.1

- Upgrade to ruby_parser 3.13.0 that fully supports Ruby 2.6

## 0.5.0

- New style of outputting offenses: `spec/support/output/sample_code.rb:1 For loop is slower than using each.`

## 0.4.1
- Upgrade ruby parser version to 3.11.0 (to stop warnings)

## 0.4.0
- Better error message on each_key
- Update Ruby Parser to ~> 3.9
- Support Ruby 2.3

[Keep a Changelog]: https://keepachangelog.com
[Semantic Versioning]: https://semver.org/spec/v2.0.0.html
[Unreleased]: https://github.com/ExtractableMedia/fastererer/compare/v0.12.0...HEAD
[0.12.0]: https://github.com/ExtractableMedia/fastererer/compare/v0.11.0...v0.12.0
[#1]: https://github.com/ExtractableMedia/fastererer/pull/1
[#2]: https://github.com/ExtractableMedia/fastererer/pull/2
[#9]: https://github.com/ExtractableMedia/fastererer/pull/9
[#15]: https://github.com/ExtractableMedia/fastererer/pull/15
[#42]: https://github.com/ExtractableMedia/fastererer/pull/42
