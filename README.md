# Fastererer

[![CI](https://github.com/ExtractableMedia/fastererer/actions/workflows/ci.yml/badge.svg)](https://github.com/ExtractableMedia/fastererer/actions/workflows/ci.yml)
[![Gem Version](https://badge.fury.io/rb/fastererer.svg)](https://badge.fury.io/rb/fastererer)
[![Gem Downloads](https://img.shields.io/gem/dt/fastererer.svg)](https://rubygems.org/gems/fastererer)

[Roadmap][roadmap-project] |
[Changelog](./CHANGELOG.md) |
[Contributing](./CONTRIBUTING.md)

`fastererer` is a static analyzer that suggests speed improvements for Ruby code, inspired by
[fast-ruby][fast-ruby] and [Sferik's talk at Baruco Conf][sferik-talk]. It's a maintained fork of
[fasterer][fasterer] with Ruby 3.3+ support and native [Prism][prism] parsing.

Suggestions aren't gospel — many trade clarity for marginal speed gains. Use judgment,
especially in non-performance-critical Rails code; the wins matter most in hot paths like web
frameworks and request middleware.

## Installation

Add to your `Gemfile`:

```ruby
group :development do
  gem 'fastererer', require: false
end
```

Then run `bundle install`. Or install directly:

```shell
gem install fastererer
```

Fastererer requires Ruby 3.3 or higher.

## Usage

Run from the root of your project to scan everything:

```shell
bundle exec fastererer
```

Pass a path to scan a specific file or directory:

```shell
bundle exec fastererer app/models
bundle exec fastererer app/models/post.rb
```

Fastererer exits with status `1` when offenses are found, making it suitable for CI.

## Example output

Each offense is reported on a single line, following the same shape as
RuboCop and its plugins (`path:line: SEVERITY: Department/RuleName: message.
(url)`), so the rule name and a link to documentation are always visible:

```text
app/models/post.rb:57: W: Performance/SelectFirstVsDetect: Array#select.first is slower than Array#detect. (https://github.com/JuanitoFatas/fast-ruby#enumerabledetect-vs-enumerableselectfirst-code)
app/models/post.rb:61: W: Performance/SelectFirstVsDetect: Array#select.first is slower than Array#detect. (https://github.com/JuanitoFatas/fast-ruby#enumerabledetect-vs-enumerableselectfirst-code)

db/seeds/cities.rb:15: W: Performance/KeysEachVsEachKey: Hash#keys.each is slower than Hash#each_key. N.B. Hash#each_key cannot be used if the hash is modified during the each block. (https://github.com/JuanitoFatas/fast-ruby#hasheach_key-instead-of-hashkeyseach-code)

test/options_test.rb:84: W: Performance/HashMergeBangVsHashBrackets: Hash#merge! with one argument is slower than Hash#[]. (https://github.com/JuanitoFatas/fast-ruby#hashmerge-vs-hash-code)

test/module_test.rb:272: W: Performance/RescueVsRespondTo: Don't rescue NoMethodError, rather check with respond_to?. (https://github.com/JuanitoFatas/fast-ruby#beginrescue-vs-respond_to-for-control-flow-code)

spec/cache/mem_cache_store_spec.rb:161: W: Performance/GsubVsTr: Using tr is faster than gsub when replacing a single character in a string with another single character. (https://github.com/JuanitoFatas/fast-ruby#stringgsub-vs-stringtr-code)
```

The rule name (e.g. `Performance/SelectFirstVsDetect`) is derived from the
underlying snake_case rule key (e.g. `select_first_vs_detect`), which is what
you reference in `.fastererer.yml` under `speedups:` to disable a rule.
Descriptions and documentation URLs live in `config/locales/en.yml`.

## Configuration

Configuration lives in a `.fastererer.yml` file at the root of your project (or any ancestor
directory). It supports two options:

* Turn individual speedup checks off
* Exclude files or directories

Example:

```yaml
speedups:
  rescue_vs_respond_to: true
  module_eval: true
  shuffle_first_vs_sample: true
  for_loop_vs_each: true
  each_with_index_vs_while: false
  map_flatten_vs_flat_map: true
  reverse_each_vs_reverse_each: true
  select_first_vs_detect: true
  sort_vs_sort_by: true
  fetch_with_argument_vs_block: true
  keys_each_vs_each_key: true
  hash_merge_bang_vs_hash_brackets: true
  block_vs_symbol_to_proc: true
  proc_call_vs_yield: true
  gsub_vs_tr: true
  select_last_vs_reverse_detect: true
  getter_vs_attr_reader: true
  setter_vs_attr_writer: true
  include_vs_cover_on_range: true

exclude_paths:
  - 'vendor/**/*.rb'
  - 'db/schema.rb'
```

## CI integration

Fastererer's non-zero exit status on offenses makes it drop-in for CI. A minimal GitHub Actions
step:

```yaml
- name: Run fastererer
  run: bundle exec fastererer
```

Color output is auto-disabled when STDOUT isn't a TTY, when `NO_COLOR` is set (see
[no-color.org](https://no-color.org/)), or when `--no-color` is passed — so CI logs, piped output
(`fastererer | grep`), and editor integrations get plain text without configuration.

## Migrating from fasterer

`fastererer` is a hard fork of [fasterer][fasterer] at v0.11.0. To migrate an existing project:

1. Replace `gem 'fasterer'` with `gem 'fastererer'` in your `Gemfile`
2. Rename `.fasterer.yml` to `.fastererer.yml`
3. Update CI commands from `fasterer` to `fastererer`

## Roadmap

Roadmap items are tracked in the [Fastererer Roadmap][roadmap-project] project.

## Questions?

Have a question? Start a [discussion][discussions] — questions, ideas, and show-and-tell are all
welcome there.

## Bugs?

Found a bug? [Open an issue][issues] or send a pull request.

## Development

Clone the repo and run `bin/setup` to install dependencies. Run tests with `bin/rspec`. See
[CONTRIBUTING.md](./CONTRIBUTING.md) for the full development workflow.

## License

Fastererer is released under the [MIT License](./LICENSE.txt).

## Code of Conduct

Everyone interacting in this project's codebases, issue trackers, and discussions is expected to
follow the [Code of Conduct](./CODE_OF_CONDUCT.md).

## Special Thanks

Fastererer carries forward [Damir Svrtan][damir-svrtan]'s [fasterer][fasterer] (v0.11.0 was the
fork point). Thanks to Damir for the original work, and to the [fast-ruby][fast-ruby] community
for the idiom catalog that drives the speed checks.

[damir-svrtan]: https://github.com/DamirSvrtan
[discussions]: https://github.com/ExtractableMedia/fastererer/discussions
[fast-ruby]: https://github.com/fastruby/fast-ruby
[fasterer]: https://github.com/DamirSvrtan/fasterer
[issues]: https://github.com/ExtractableMedia/fastererer/issues
[prism]: https://github.com/ruby/prism
[roadmap-project]: https://github.com/orgs/ExtractableMedia/projects/1
[sferik-talk]: https://speakerdeck.com/sferik/writing-fast-ruby
