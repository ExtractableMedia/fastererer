# Implementation Plan: MCP Server for Fastererer

**Issue:** [#44 — Add built-in MCP server support for AI-assisted development](https://github.com/ExtractableMedia/fastererer/issues/44)

## Overview

Add a built-in Model Context Protocol (MCP) server to fastererer, invoked via `fastererer --mcp`. The server runs over stdio and exposes fastererer's performance analysis as structured tool calls for AI coding assistants.

## Architecture

```
exe/fastererer
    ↓
CLI.execute
    ├── (existing) FileTraverser path → text output
    └── (new) --mcp flag → Fastererer::MCP::Server.new.start
                                ↓
                          mcp gem (stdio transport)
                                ↓
                    ┌──────────────────────────────┐
                    │  Tool: fastererer_inspection  │ → Analyzer + OffenseCollector → JSON
                    │  Tool: fastererer_list_checks │ → Config + Offense::EXPLANATIONS → JSON
                    └──────────────────────────────┘
```

> **Namespace note:** The `mcp` gem defines a top-level `::MCP` module. Like
> RuboCop (`RuboCop::MCP::Server`), we use `Fastererer::MCP::Server` and
> qualify all gem references with the `::` prefix (`::MCP::Server`,
> `::MCP::Tool`, etc.) to avoid the shadowing issue. This matches RuboCop's
> convention exactly.

## Step 1: Refactor `Analyzer` to accept content directly

**File:** `lib/fastererer/analyzer.rb`

Currently `Analyzer.new(file_path)` reads the file in the constructor. Add an optional `content:` keyword arg so the MCP inspection tool can pass inline source code without a tempfile:

```ruby
def initialize(file_path, content: nil)
  @file_path = file_path.to_s
  @file_content = content || File.read(file_path)
end
```

This is backward-compatible — the two existing call sites (`FileTraverser#scan_file` and specs) pass only a positional arg. `ruby_parser` operates on strings, so it doesn't care whether the content came from a file or was passed directly.

When `content:` is provided, `file_path` is a synthetic label. Following RuboCop's convention, use `'example.rb'` as the default filename when `source_code` is provided without a `path` — this allows config file-pattern matching to work correctly.

Add a test immediately: pass a `content:` string with a known offense, verify `scan` finds it without any file on disk.

## Step 2: Add `mcp` gem as an optional dependency

**Files:** `Gemfile`

Add `mcp` (~> 0.17) to the Gemfile for development/CI convenience (matching RuboCop's approach):

```ruby
gem 'mcp', '~> 0.17'
```

Do NOT add it to `spec.add_dependency` in the gemspec. Ruby has no native optional dependencies — the right pattern is:

- Gemspec: no mention of `mcp`
- Runtime: lazy `require 'mcp'` with `rescue LoadError` and runtime version check
- README: document the optional dependency

This matches RuboCop exactly: their gemspec has no `mcp` dependency, their Gemfile has `gem 'mcp', '~> 0.16'` for development, and `server.rb` handles the optional require at runtime.

## Step 3: Create `Fastererer::MCP::Server` with both tools

**New file:** `lib/fastererer/mcp/server.rb`

Single file containing the server class and both tool definitions. Follows RuboCop's structure exactly: `RuboCop::MCP::Server` → `Fastererer::MCP::Server`.

### Dependency loading (top of file)

Following RuboCop's pattern, the `mcp` gem is loaded and version-checked at the top of `server.rb`, outside any class. This runs only when the file is required (i.e., only when `--mcp` is passed):

```ruby
begin
  require 'mcp'

  required_mcp_version = '0.6.0'

  if Gem::Version.new(required_mcp_version) > Gem::Version.new(MCP::VERSION)
    warn <<~MESSAGE
      Error: `mcp` gem version #{MCP::VERSION} was loaded, but `fastererer --mcp` requires #{required_mcp_version}.
      - If you're using Bundler, add `gem 'mcp', '~> 0.6'` to your Gemfile.
      - Otherwise, run `gem update mcp`.
    MESSAGE
    exit!
  end
rescue LoadError => e
  raise unless e.path == 'mcp'

  warn <<~MESSAGE
    Error: Unable to load `mcp` gem. Add `gem 'mcp', '~> 0.6'` to your Gemfile, or run `gem install mcp`.
  MESSAGE

  exit!
end
```

Key details matching RuboCop:
- `rescue LoadError => e` with `raise unless e.path == 'mcp'` — only catches `mcp` load failures, re-raises unrelated ones
- Runtime version check with `Gem::Version` — minimum 0.6.0
- `exit!` (hard exit, no `at_exit` hooks) on failure
- User-facing instructions tell them to add `gem 'mcp', '~> 0.6'` (the minimum, not our dev pin)

### Server class

```ruby
module Fastererer
  module MCP
    class Server
      def initialize
        @config = Fastererer::Config.new
      end

      def start
        server = ::MCP::Server.new(
          name: 'fastererer_mcp_server',
          version: Fastererer::VERSION,
          tools: [inspection_tool, list_checks_tool]
        )

        ::MCP::Server::Transports::StdioTransport.new(server).open
      end
    end
  end
end
```

Note: all references to the gem's MCP module use the `::` prefix (`::MCP::Server`, `::MCP::Tool`, etc.) to disambiguate from our own `Fastererer::MCP` namespace. This matches RuboCop's approach.

> **`$stdout` contamination warning:** MCP stdio transport communicates over
> `$stdin`/`$stdout`. Any `puts`/`print` to `$stdout` corrupts the JSON-RPC
> stream. The MCP code path must never call `FileTraverser` or `Painter`
> (which both write to `$stdout`). The `Analyzer` class is safe — it only
> reads files and builds data structures.

### `fastererer_inspection` tool

Defined via `::MCP::Tool.define` (matching RuboCop's pattern — not subclasses):

```ruby
def inspection_tool
  config = @config

  ::MCP::Tool.define(
    name: 'fastererer_inspection',
    description: 'Inspect Ruby code for performance anti-patterns and return structured results',
    input_schema: {
      properties: {
        path: { type: 'string' },
        source_code: { type: 'string' }
      }
    },
    annotations: {
      title: "Fastererer's inspection",
      read_only_hint: true,
      destructive_hint: false,
      idempotent_hint: true,
      open_world_hint: false
    }
  ) do |path: nil, source_code: nil|
    raise Fastererer::Error, "Provide either 'path' or 'source_code', not both" if path && source_code
    raise Fastererer::Error, "Provide either 'path' or 'source_code'" if !path && !source_code

    analyzer = if source_code
                 Fastererer::Analyzer.new(path || 'example.rb', content: source_code)
               else
                 Fastererer::Analyzer.new(path)
               end
    analyzer.scan

    ignored = config.ignored_speedups

    offenses = analyzer.errors
      .group_by(&:name)
      .reject { |name, _| ignored.include?(name) }
      .flat_map do |name, occurrences|
        occurrences.map do |offense|
          {
            offense: offense.name.to_s,
            line: offense.line,
            explanation: offense.explanation,
            file: analyzer.file_path
          }
        end
      end

    ::MCP::Tool::Response.new([{ type: 'text', text: offenses.to_json }])
  rescue Fastererer::Error => e
    ::MCP::Tool::Response.new([{ type: 'text', text: e.message }], error: true)
  end
end
```

### `fastererer_list_checks` tool

```ruby
def list_checks_tool
  config = @config

  ::MCP::Tool.define(
    name: 'fastererer_list_checks',
    description: 'List all available performance checks and their enabled/disabled status',
    input_schema: { properties: {} },
    annotations: {
      title: "Fastererer's list checks",
      read_only_hint: true,
      destructive_hint: false,
      idempotent_hint: true,
      open_world_hint: false
    }
  ) do
    ignored = config.ignored_speedups

    checks = Fastererer::Offense::EXPLANATIONS.each_with_object({}) do |(name, explanation), hash|
      hash[name.to_s] = {
        enabled: !ignored.include?(name),
        explanation: explanation
      }
    end

    ::MCP::Tool::Response.new([{ type: 'text', text: checks.to_json }])
  end
end
```

### Error handling pattern

Following RuboCop's approach: catch specific errors and re-raise as a single `Fastererer::Error`, which the tool block rescues and returns as `::MCP::Tool::Response.new([...], error: true)`.

This requires adding a simple error class (if one doesn't already exist):

```ruby
module Fastererer
  class Error < StandardError; end
end
```

Errors to catch and wrap in the inspection tool:
- `RubyParser::SyntaxError`, `Racc::ParseError` → "Parse error: ..."
- `Timeout::Error` → "Analysis timed out"
- `Errno::ENOENT` → "No such file or directory: ..."
- `Encoding::UndefinedConversionError`, `Encoding::InvalidByteSequenceError` → "Encoding error: ..."

**Notes on `Config` behavior:** `Config.new` searches for `.fastererer.yml` upward from `Dir.pwd`. In MCP mode, the working directory is whatever the MCP client sets (typically the project root). This is correct — the config is project-specific and matches CLI behavior.

## Step 4: Wire `--mcp` flag into the CLI

**File:** `lib/fastererer/cli.rb`

Add a `--mcp` option to `build_parser`:

```ruby
opts.on('--mcp', 'Start MCP server (experimental)') { options[:mcp] = true }
```

In `execute`, check for the flag before the normal traversal flow:

```ruby
def self.execute
  options = parse_options(ARGV.dup)
  if options[:mcp]
    require_relative 'mcp/server'
    Fastererer::MCP::Server.new.start
    return
  end
  Painter.disable! if options[:no_color]
  file_traverser = Fastererer::FileTraverser.new(options[:path])
  file_traverser.traverse
  abort if file_traverser.offenses_found?
end
```

The `require_relative 'mcp/server'` is lazy — the `mcp` gem is only loaded when `--mcp` is actually passed. This matches RuboCop's pattern where their CLI command does `require_relative '../../mcp/server'` inside the `run` method.

## Step 5: Add tests

**New files:**
- `spec/lib/fastererer/mcp/server_spec.rb`
- `spec/support/mcp_helper.rb` — helper for running the server with `StringIO` stdin/stdout (matching RuboCop's `spec/support/mcp_helper.rb` pattern)

**Conditional execution:** Since `mcp` is optional, MCP specs must skip gracefully:

```ruby
begin
  require 'mcp'
  MCP_AVAILABLE = true
rescue LoadError
  MCP_AVAILABLE = false
end

RSpec.describe Fastererer::MCP::Server, if: MCP_AVAILABLE do
  # ...
end
```

**Test cases:**

1. **Analyzer `content:` kwarg** — pass inline code with a known offense, verify `scan` detects it
2. **InspectionTool with `path:`** — point at a fixture file with offenses, verify structured JSON response
3. **InspectionTool with `source_code:`** — pass inline Ruby, verify offenses returned
4. **InspectionTool validation** — both params → error, neither param → error
5. **InspectionTool error handling** — invalid Ruby → parse error response, missing file → file not found response
6. **InspectionTool respects config** — ignored speedups are filtered out
7. **ListChecksTool** — returns all checks from `EXPLANATIONS` with correct enabled/disabled status
8. **ListChecksTool with config** — disabled speedups show `enabled: false`
9. **CLI flag parsing** — `--mcp` is recognized
10. **Integration smoke test** — instantiate `::MCP::Server` with both tools, send a `tools/list` JSON-RPC request, verify both tools appear in the response

Use the existing `isolated environment` shared context for tests that depend on Config (it `chdir`s into a tmpdir, preventing pickup of the repo's own `.fastererer.yml`).

## File Structure (New Files)

```
lib/fastererer/
├── mcp/
│   └── server.rb              # Dependency loading, server class, tool definitions
spec/lib/fastererer/
├── mcp/
│   └── server_spec.rb         # All MCP-related tests
spec/support/
├── mcp_helper.rb              # StringIO-based server test helper
```

## Dependency Notes

- **`mcp` gem:** Optional. Only loaded when `--mcp` is used. Not in gemspec `add_dependency`. Minimum runtime version: `0.6.0` (enforced at load time). Development Gemfile pins `~> 0.17`. Users told to add `gem 'mcp', '~> 0.6'` to their Gemfile.
- **No other new dependencies.**
- **Ruby >= 3.3:** Already required; no change needed.

## Implementation Order

All steps in a single PR:

1. Refactor `Analyzer` to accept `content:` + add test (2-line change, zero risk)
2. Add `mcp` gem to Gemfile `:mcp` group
3. Create `Fastererer::MCP::Server` with both tools
4. Wire `--mcp` flag into CLI
5. Add tests (alongside each step, not after)

Estimated size: ~150-200 lines of new Ruby code + ~150 lines of tests.

## Resolved Questions

1. **Tool naming:** Use `fastererer_` prefix (e.g., `fastererer_inspection`). Matches RuboCop's `rubocop_inspection` / `rubocop_autocorrection` convention.
2. **Tempfile vs Analyzer refactor:** Do the Analyzer refactor upfront (Step 1). It's a 2-line backward-compatible change that eliminates the need for tempfiles entirely.
3. **`mcp` gem version:** Development Gemfile pins `~> 0.17`. Runtime enforces minimum `0.6.0` with `Gem::Version` check. User-facing docs say `~> 0.6`. This mirrors RuboCop (dev Gemfile `~> 0.16`, runtime minimum `0.6.0`, docs say `~> 0.6`).
4. **Tool definition style:** Use `::MCP::Tool.define` (factory with block), not `MCP::Tool` subclasses. Matches RuboCop. Simpler, tool blocks receive input schema properties as keyword args directly.
5. **Namespace:** Use `Fastererer::MCP::Server` (matching `RuboCop::MCP::Server`), with `::` prefix on all gem references. Both reviewers flagged the collision risk — the `::` prefix is how RuboCop handles it in production.
6. **Default filename for inline code:** Use `'example.rb'` when `source_code` is provided without `path`, matching RuboCop's convention (allows config pattern matching to work).
7. **`server_context:` kwarg:** Not used. RuboCop's tool blocks don't accept it — they only receive input schema properties as keyword args. Our tools follow the same pattern.
