# Fastererer

[![CI](https://github.com/ExtractableMedia/fastererer/actions/workflows/ci.yml/badge.svg)](https://github.com/ExtractableMedia/fastererer/actions/workflows/ci.yml)

`fastererer` is a maintained fork of [fasterer][fasterer] (originally by
[Damir Svrtan][damir-svrtan]), updated for Ruby 4.0 and built on the [Prism][prism] parser.

Make your Rubies go faster with this command line tool highly inspired by
[fast-ruby][fast-ruby] and [Sferik's talk at Baruco Conf][sferik-talk].

Fastererer will suggest some speed improvements which you can check in detail at the
[fast-ruby repo][fast-ruby].

**Please note** that you shouldn't follow the suggestions blindly. Using a while loop instead of
a each_with_index probably shouldn't be considered if you're doing a regular Rails project, but
maybe if you're doing something very speed dependent such as Rack or if you're building your own
framework, you might consider this speed increase.



## Installation

```shell
gem install fastererer
```

## Usage

Run it from the root of your project:

```shell
fastererer
```

## Example output

```text
app/models/post.rb:57 Array#select.first is slower than Array#detect.
app/models/post.rb:61 Array#select.first is slower than Array#detect.

db/seeds/cities.rb:15 Hash#keys.each is slower than Hash#each_key.
db/seeds/cities.rb:33 Hash#keys.each is slower than Hash#each_key.

test/options_test.rb:84 Hash#merge! with one argument is slower than Hash#[].

test/module_test.rb:272 Don't rescue NoMethodError, rather check with respond_to?.

spec/cache/mem_cache_store_spec.rb:161 Use tr instead of gsub when grepping plain strings.
```
## Configuration

Configuration is done through the **.fastererer.yml** file. This can placed in the root of your
project, or any ancestor folder.

Options:

* Turn off speed suggestions
* Blacklist files or complete folder paths

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

exclude_paths:
  - 'vendor/**/*.rb'
  - 'db/schema.rb'
```

## Relationship to fasterer

`fastererer` is a hard fork of [fasterer][fasterer] at v0.11.0. It carries forward the original
work and adds:

- Support for Ruby 3.3+ (drops EOL Rubies 2.x, 3.0, 3.1, 3.2) and Ruby 4.0
- Native [Prism][prism] parsing (replaces the EOL `ruby_parser` dependency)
- Active maintenance and security updates

Existing projects migrating from `fasterer` should:

1. Replace `gem 'fasterer'` with `gem 'fastererer'` in their Gemfile
2. Rename `.fasterer.yml` to `.fastererer.yml`
3. Update CI commands from `fasterer` to `fastererer`

## Roadmap

4. find vs bsearch
5. Array#count vs Array#size
7. Enumerable#each + push vs Enumerable#map
17. Hash#merge vs Hash#merge!
20. String#casecmp vs String#downcase + ==
21. String concatenation
22. String#match vs String#start_with?/String#end_with?
23. String#gsub vs String#sub

## Contributing

Bug reports and pull requests are welcome. See [CONTRIBUTING.md](CONTRIBUTING.md) for the issue,
PR, and local development workflow.

## Code of Conduct

Everyone interacting in this project's codebases, issue trackers, and discussions is expected to
follow the [Code of Conduct](CODE_OF_CONDUCT.md).

[damir-svrtan]: https://github.com/DamirSvrtan
[fast-ruby]: https://github.com/JuanitoFatas/fast-ruby
[fasterer]: https://github.com/DamirSvrtan/fasterer
[prism]: https://github.com/ruby/prism
[sferik-talk]: https://speakerdeck.com/sferik/writing-fast-ruby
