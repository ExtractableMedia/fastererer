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
    └── (new) --mcp flag → Fastererer::McpServer.start
                                ↓
                          mcp gem (stdio transport)
                                ↓
                    ┌──────────────────────────────┐
                    │  Tool: fastererer_inspection  │ → Analyzer + OffenseCollector → JSON
                    │  Tool: fastererer_list_checks │ → Config + Offense::EXPLANATIONS → JSON
                    └──────────────────────────────┘
```

> **Why `McpServer` and not `MCP`?** The `mcp` gem defines a top-level `::MCP` module.
> Naming our namespace `Fastererer::MCP` would shadow it — bare references to
> `MCP::Server` inside the module would resolve to `Fastererer::MCP::Server`
> (infinite recursion / `NameError`), not `::MCP::Server`. Using `McpServer`
> eliminates this entirely.

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

When `content:` is provided, `file_path` is a synthetic label (e.g., `"(source_code)"`). The MCP tool will use this as the `file` field in JSON output for inline analysis.

Add a test immediately: pass a `content:` string with a known offense, verify `scan` finds it without any file on disk.

## Step 2: Add `mcp` gem as an optional dependency

**Files:** `Gemfile`

Add `mcp` (~> 0.17) to the Gemfile in a `:mcp` group for development/CI convenience:

```ruby
group :mcp do
  gem 'mcp', '~> 0.17'
end
```

Do NOT add it to `spec.add_dependency` in the gemspec. Ruby has no native optional dependencies — the right pattern is:

- Gemspec: no mention of `mcp`
- Runtime: lazy `require 'mcp'` with `rescue LoadError` and a clear install instruction
- README: document the optional dependency

The `mcp` gem is at 0.17.0 (May 2026) with significant API changes since 0.6. Pinning `~> 0.17` ensures compatibility with the current tool class API (`MCP::Tool` subclasses, `server_context:` kwarg, `StdioTransport`).

## Step 3: Create `Fastererer::McpServer` with both tools

**New file:** `lib/fastererer/mcp_server.rb`

Single file containing the server class and both tool definitions inline. Two tools with ~25 lines each don't warrant a subdirectory structure — if more tools are added later, extraction is trivial.

### Server setup

```ruby
module Fastererer
  class McpServer
    def self.start
      require_mcp_gem!
      server = ::MCP::Server.new(
        name: "fastererer",
        version: Fastererer::VERSION,
        instructions: "Analyze Ruby code for performance anti-patterns. " \
                      "Use fastererer_inspection to check a file or code snippet, " \
                      "fastererer_list_checks to see available checks and their config status.",
        tools: [InspectionTool, ListChecksTool]
      )
      transport = ::MCP::Server::Transports::StdioTransport.new(server)
      transport.open
    end

    def self.require_mcp_gem!
      require 'mcp'
    rescue LoadError
      warn "The 'mcp' gem is required for MCP server mode. Install it with: gem install mcp"
      exit 1
    end
  end
end
```

> **`$stdout` contamination warning:** MCP stdio transport communicates over
> `$stdin`/`$stdout`. Any `puts`/`print` to `$stdout` corrupts the JSON-RPC
> stream. The MCP code path must never call `FileTraverser` or `Painter`
> (which both write to `$stdout`). The `Analyzer` class is safe — it only
> reads files and builds data structures.

### `InspectionTool`

```ruby
class Fastererer::McpServer::InspectionTool < ::MCP::Tool
  tool_name "fastererer_inspection"
  description "Inspect Ruby code for performance anti-patterns and return structured results"

  input_schema(
    properties: {
      path: { type: "string", description: "Path to a Ruby file on disk to inspect" },
      source_code: { type: "string", description: "Inline Ruby source code to inspect" }
    }
  )

  annotations(
    title: "Fastererer Inspection",
    read_only_hint: true,
    destructive_hint: false,
    idempotent_hint: true,
    open_world_hint: false
  )

  def self.call(path: nil, source_code: nil, server_context:)
    return error_response("Provide either 'path' or 'source_code', not both") if path && source_code
    return error_response("Provide either 'path' or 'source_code'") if !path && !source_code

    analyzer = if source_code
                 Fastererer::Analyzer.new("(source_code)", content: source_code)
               else
                 Fastererer::Analyzer.new(path)
               end
    analyzer.scan

    config = Fastererer::Config.new
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

    ::MCP::Tool::Response.new([{ type: "text", text: offenses.to_json }])
  rescue RubyParser::SyntaxError, Racc::ParseError => e
    error_response("Parse error: #{e.message}")
  rescue Timeout::Error
    error_response("Analysis timed out")
  rescue Errno::ENOENT => e
    error_response("File not found: #{e.message}")
  rescue Encoding::UndefinedConversionError, Encoding::InvalidByteSequenceError => e
    error_response("Encoding error: #{e.message}")
  end

  def self.error_response(message)
    ::MCP::Tool::Response.new([{ type: "text", text: message }], error: true)
  end
end
```

### `ListChecksTool`

```ruby
class Fastererer::McpServer::ListChecksTool < ::MCP::Tool
  tool_name "fastererer_list_checks"
  description "List all available performance checks and their enabled/disabled status"

  annotations(
    title: "Fastererer List Checks",
    read_only_hint: true,
    destructive_hint: false,
    idempotent_hint: true,
    open_world_hint: false
  )

  def self.call(server_context:)
    config = Fastererer::Config.new
    ignored = config.ignored_speedups

    checks = Fastererer::Offense::EXPLANATIONS.each_with_object({}) do |(name, explanation), hash|
      hash[name.to_s] = {
        enabled: !ignored.include?(name),
        explanation: explanation
      }
    end

    ::MCP::Tool::Response.new([{ type: "text", text: checks.to_json }])
  end
end
```

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
    require_relative 'mcp_server'
    Fastererer::McpServer.start
    return
  end
  Painter.disable! if options[:no_color]
  file_traverser = Fastererer::FileTraverser.new(options[:path])
  file_traverser.traverse
  abort if file_traverser.offenses_found?
end
```

## Step 5: Add tests

**New files:**
- `spec/lib/fastererer/mcp_server_spec.rb`

**Conditional execution:** Since `mcp` is optional, MCP specs must skip gracefully:

```ruby
begin
  require 'mcp'
  MCP_AVAILABLE = true
rescue LoadError
  MCP_AVAILABLE = false
end

RSpec.describe Fastererer::McpServer, if: MCP_AVAILABLE do
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
├── mcp_server.rb          # Server class + both tool definitions
spec/lib/fastererer/
├── mcp_server_spec.rb     # All MCP-related tests
```

## Dependency Notes

- **`mcp` gem (~> 0.17):** Optional. Only loaded when `--mcp` is used. Not in gemspec `add_dependency`. Documented in README.
- **No other new dependencies.**
- **Ruby >= 3.3:** Already required; no change needed.

## Implementation Order

All steps in a single PR:

1. Refactor `Analyzer` to accept `content:` + add test (2-line change, zero risk)
2. Add `mcp` gem to Gemfile `:mcp` group
3. Create `Fastererer::McpServer` with both tools
4. Wire `--mcp` flag into CLI
5. Add tests (alongside each step, not after)

Estimated size: ~150-200 lines of new Ruby code + ~150 lines of tests.

## Resolved Questions

1. **Tool naming:** Use `fastererer_` prefix (e.g., `fastererer_inspection`). Avoids collisions when multiple MCP servers are registered. Matches RuboCop's convention. Some MCP clients auto-prefix with the server name, but not all do.
2. **Tempfile vs Analyzer refactor:** Do the Analyzer refactor upfront (Step 1). It's a 2-line backward-compatible change that eliminates the need for tempfiles entirely. No concurrency issues, no encoding edge cases, no cleanup logic.
3. **`mcp` gem version:** Pin `~> 0.17` to match the current API (`MCP::Tool` subclasses, `server_context:`, `StdioTransport`, annotations).
