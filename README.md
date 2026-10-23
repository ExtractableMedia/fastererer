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

Fastererer exits with status `1` when offenses are found and `2` when the path it was given does not
exist, making it suitable for CI. See [Exit codes](#exit-codes).

## Example output

Each offense is reported on a single line, following the same shape as
RuboCop and its plugins (`path:line: SEVERITY: Department/RuleName: message.
(url)`), so the rule name and a link to documentation are always visible:

```text
app/models/post.rb:57: W: Performance/SelectFirstVsDetect: Array#select.first is slower than Array#detect. (https://github.com/fastruby/fast-ruby#enumerabledetect-vs-enumerableselectfirst-code)
app/models/post.rb:61: W: Performance/SelectFirstVsDetect: Array#select.first is slower than Array#detect. (https://github.com/fastruby/fast-ruby#enumerabledetect-vs-enumerableselectfirst-code)

db/seeds/cities.rb:15: W: Performance/KeysEachVsEachKey: Hash#keys.each is slower than Hash#each_key. N.B. Hash#each_key cannot be used if the hash is modified during the each block. (https://github.com/fastruby/fast-ruby#hasheach_key-instead-of-hashkeyseach-code)

test/options_test.rb:84: W: Performance/HashMergeBangVsHashBrackets: Hash#merge! with one argument is slower than Hash#[]. (https://github.com/fastruby/fast-ruby#hashmerge-vs-hash-code)

test/module_test.rb:272: W: Performance/RescueVsRespondTo: Don't rescue NoMethodError, rather check with respond_to?. (https://github.com/fastruby/fast-ruby#beginrescue-vs-respond_to-for-control-flow-code)

spec/cache/mem_cache_store_spec.rb:161: W: Performance/GsubVsTr: Using tr is faster than gsub when replacing a single character in a string with another single character. (https://github.com/fastruby/fast-ruby#stringgsub-vs-stringtr-code)
```

The rule name (e.g. `Performance/SelectFirstVsDetect`) is derived from the
underlying snake_case rule key (e.g. `select_first_vs_detect`), which is what
you reference in `.fastererer.yml` under `speedups:` to disable a rule.
Descriptions and documentation URLs live in `config/locales/en.yml`.

## Output formats

By default fastererer prints the human-readable text shown above. Pass `-f`/`--format` to emit
machine-readable output for editors, log aggregators, or CI reporters instead:

```shell
fastererer --format=json      # single JSON document, includes a run summary
fastererer --format=rdjsonl   # reviewdog JSON Lines, one record per offense
fastererer --format=text      # the default
```

Machine formats write only their payload to stdout; diagnostics (parse errors, a missing path)
go to stderr, so `fastererer --format=json > findings.json` captures clean JSON. An unrecognized
format name is a usage error: the name is reported on stderr and fastererer exits `2` without
scanning.

`--format=json` produces one document with a `summary` of run counts and a flat `offenses` array
(each offense carries `path`, `line`, `rule`, `rule_key`, `message`, and `url`). `rule` is the
display name; `rule_key` is the identifier to write under `speedups:` in `.fastererer.yml`, so a
consumer can offer to silence a rule without guessing at the name:

```json
{
  "metadata": { "fastererer_version": "1.0.0" },
  "summary": { "offense_count": 1, "inspected_file_count": 12, "unparsable_file_count": 0 },
  "offenses": [
    {
      "path": "app/models/post.rb",
      "line": 57,
      "rule": "Performance/SelectFirstVsDetect",
      "rule_key": "select_first_vs_detect",
      "message": "Array#select.first is slower than Array#detect",
      "url": "https://github.com/fastruby/fast-ruby#enumerabledetect-vs-enumerableselectfirst-code"
    }
  ]
}
```

`--format=rdjsonl` follows the [reviewdog Diagnostic Format][rdf], one JSON object per line, ready
to pipe straight into reviewdog (see [CI integration](#ci-integration)). `code.value` carries the
rule key rather than the display name, because reviewdog renders it into the pull request comment
and the key is the name a reader can act on — the one to add under `speedups:` in `.fastererer.yml`:

```json
{"message":"Array#select.first is slower than Array#detect","location":{"path":"app/models/post.rb","range":{"start":{"line":57}}},"severity":"WARNING","code":{"value":"select_first_vs_detect","url":"https://github.com/fastruby/fast-ruby#enumerabledetect-vs-enumerableselectfirst-code"}}
```

## Configuration

Fastererer works with no configuration. Out of the box every speedup is active, and `tmp/`,
`vendor/` and `node_modules/` are skipped.

Add a `.fastererer.yml` at the root of your project (or any ancestor directory) only when you want
to change something. The file holds **your overrides**: anything you leave out keeps the value
fastererer ships with, so you never restate the full list.

### Turning a speedup off

List only the speedups you want to change. Every speedup you don't mention stays on.

```yaml
speedups:
  each_with_index_vs_while: false
  gsub_vs_tr: false
```

Only an explicit `false` switches a speedup off. Writing `true` is allowed but never necessary, and
a key with no value at all inherits the shipped default rather than being read as off.

The keys are the snake_case names listed under [Available speedups](#available-speedups). Offense
output shows the same rule in its display form: `gsub_vs_tr` reports as `Performance/GsubVsTr`.

### Excluding files and directories

Fastererer already skips `tmp/**/*.rb`, `vendor/**/*.rb` and `node_modules/**/*.rb`. Add your own:

```yaml
exclude_paths:
  - 'db/schema.rb'
```

> **Note:** Paths you list here are **added to** the three defaults above, not substituted for
> them. This differs from RuboCop, where `AllCops/Exclude` replaces the shipped list and adding one
> entry silently drops the rest.

Globs resolve relative to the directory you run from. A file named directly on the command line is
always scanned, even when `exclude_paths` matches it, so `fastererer vendor/foo.rb` inspects that
file rather than reporting a clean scan.

### When a new speedup ships

A release may add new speedups. Turning one on for everyone the moment they upgrade would change
what fails your build without you asking, so a newly added speedup starts out **held back**:
fastererer names it once on the error stream and reports no offenses for it. Upgrading never turns
a green build red on its own.

`new_speedups` decides what happens to held-back speedups:

| Value | What happens |
| ----- | ------------ |
| `warn` | They are named on the error stream, report no offenses, and do not affect the exit status. This is what you get if you don't set it. |
| `enable` | They are active as soon as you upgrade. |
| `disable` | They stay off, silently. |

```yaml
new_speedups: enable
```

Naming a speedup under `speedups:` yourself always wins over `new_speedups`, so you can adopt them
one at a time. `pending` is accepted as a synonym for `warn`, for anyone with RuboCop's `NewCops`
in muscle memory.

### Available speedups

```text
block_vs_symbol_to_proc            keys_each_vs_each_key
each_with_index_vs_while           map_flatten_vs_flat_map
fetch_with_argument_vs_block       module_eval
for_loop_vs_each                   proc_call_vs_yield
getter_vs_attr_reader              rescue_vs_respond_to
gsub_vs_tr                         reverse_each_vs_reverse_each
hash_merge_bang_vs_hash_brackets   select_first_vs_detect
include_vs_cover_on_range          select_last_vs_reverse_detect
setter_vs_attr_writer              shuffle_first_vs_sample
sort_vs_sort_by
```

## CI integration

Fastererer's non-zero exit status on offenses makes it drop-in for CI. A minimal GitHub Actions
step:

```yaml
- name: Run fastererer
  run: bundle exec fastererer
```

### Exit codes

| Status | Meaning |
| ------ | ------- |
| `0` | The scan completed and no offenses were found |
| `1` | The scan completed and offenses were found |
| `2` | Usage error — an unknown flag or format, a path that does not exist, or a `.fastererer.yml` that cannot be read, so nothing was scanned |

Status `2` is kept distinct from `1` so a wrapper script can tell "the tool ran and found problems"
from "you invoked me wrong". A renamed directory, a mistyped flag or an unknown `--format` value
fails the build instead of reporting a clean scan.

### Inline PR comments with reviewdog

The `rdjsonl` format is consumed natively by [reviewdog](https://github.com/reviewdog/reviewdog),
which can post findings as inline GitHub PR review comments:

```shell
bundle exec fastererer --format=rdjsonl \
  | reviewdog -f=rdjsonl -name=fastererer -filter-mode=nofilter -reporter=github-pr-review
```

`-filter-mode=nofilter` reports every finding, not only those on lines the pull request touched,
which is what reviewdog does by default. Findings outside the diff cannot be posted as inline
review comments — GitHub's review API does not allow it — so reviewdog falls back to check
annotations for those. `-name=fastererer` attributes the comments, since the rdjsonl record carries
no tool name of its own. `-reporter=github-pr-review` needs `pull-requests: write`.

Run fastererer from the repository root and let the path default to `.`. reviewdog matches findings
against the pull request by repository-relative path, so passing an absolute directory emits
absolute paths that will not match — and puts the runner's directory layout in a public comment.

Color output is auto-disabled when STDOUT isn't a TTY, when `NO_COLOR` is set (see
[no-color.org](https://no-color.org/)), or when `--no-color` is passed — so CI logs, piped output
(`fastererer | grep`), and editor integrations get plain text without configuration.

## Migrating from fasterer

`fastererer` is a hard fork of [fasterer][fasterer] at v0.11.0. To migrate an existing project:

1. Replace `gem 'fasterer'` with `gem 'fastererer'` in your `Gemfile`
2. Rename `.fasterer.yml` to `.fastererer.yml`
3. Update CI commands from `fasterer` to `fastererer`

Your existing file keeps working. Because a project config now layers over the defaults, you can
trim it to just the speedups you set to `false` and the paths you exclude beyond the defaults.

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
[rdf]: https://github.com/reviewdog/reviewdog/tree/master/proto/rdf
[roadmap-project]: https://github.com/orgs/ExtractableMedia/projects/1
[sferik-talk]: https://speakerdeck.com/sferik/writing-fast-ruby
