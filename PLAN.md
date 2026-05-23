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
    └── (new) --mcp flag → Fastererer::MCP::Server.start
                                ↓
                          mcp gem (stdio transport)
                                ↓
                    ┌───────────────────────┐
                    │  Tool: inspection     │ → Analyzer + OffenseCollector → JSON
                    │  Tool: list_checks    │ → Config + Offense::EXPLANATIONS → JSON
                    └───────────────────────┘
```

## Phase 1: Core MCP Server (Minimum Viable)

### Step 1: Add `mcp` gem as an optional dependency

**Files:** `fastererer.gemspec`, `Gemfile`

Add `mcp` (~> 0.6) as an optional runtime dependency. Following RuboCop's approach, it should NOT be a hard dependency — fastererer must continue to work without it installed.

- In the gemspec, do NOT add it to `add_dependency`. Instead, document it as an optional requirement.
- In the Gemfile, add it to a new `:mcp` group for development convenience.
- At runtime, `require 'mcp'` will be called lazily only when `--mcp` is used, with a clear error message if the gem is missing.

### Step 2: Create `Fastererer::MCP::Server`

**New file:** `lib/fastererer/mcp/server.rb`

This is the main server class. Responsibilities:

1. Require the `mcp` gem (with a rescue that prints an install instruction and exits)
2. Instantiate an `MCP::Server` from the `mcp` gem
3. Register the two tools (inspection, list_checks)
4. Start the stdio transport loop

```ruby
module Fastererer
  module MCP
    class Server
      def self.start
        require_mcp_gem!
        server = build_server
        register_tools(server)
        server.run(transport: :stdio)
      end

      def self.require_mcp_gem!
        require 'mcp'
      rescue LoadError
        warn "The 'mcp' gem is required for MCP server mode. Install it with: gem install mcp"
        exit 1
      end
    end
  end
end
```

### Step 3: Implement the `fastererer_inspection` tool

**New file:** `lib/fastererer/mcp/tools/inspection.rb`

This tool accepts either a file `path` or inline `source_code` and returns structured offense data.

**Parameters:**
- `path` (string, optional) — path to a Ruby file on disk
- `source_code` (string, optional) — inline Ruby source code

**Logic:**
1. Validate that exactly one of `path` or `source_code` is provided
2. If `path`: use `Fastererer::Analyzer.new(path)` directly (existing flow)
3. If `source_code`: write to a `Tempfile`, then use `Fastererer::Analyzer.new(tempfile.path)`
   - Alternative: Refactor `Analyzer` to accept a content string directly (see Phase 2)
4. Call `analyzer.scan`
5. Load `Config` and filter out `ignored_speedups`
6. Map `analyzer.errors` to structured JSON:

```json
[
  {
    "offense": "select_first_vs_detect",
    "line": 42,
    "explanation": "Array#select.first is slower than Array#detect",
    "file": "app/models/user.rb"
  }
]
```

**Error handling:**
- `RubyParser::SyntaxError`, `Racc::ParseError` → return structured error response
- `Errno::ENOENT` (file not found) → return structured error response
- `Timeout::Error` → return structured error response

### Step 4: Implement the `fastererer_list_checks` tool

**New file:** `lib/fastererer/mcp/tools/list_checks.rb`

Returns all available performance checks with their enabled/disabled status.

**Parameters:** None

**Logic:**
1. Load `Fastererer::Config`
2. Iterate `Fastererer::Offense::EXPLANATIONS`
3. For each check, report whether it's enabled (not in `ignored_speedups`)
4. Return structured JSON:

```json
{
  "select_first_vs_detect": {
    "enabled": true,
    "explanation": "Array#select.first is slower than Array#detect"
  },
  "each_with_index_vs_while": {
    "enabled": false,
    "explanation": "Using each_with_index is slower than while loop"
  }
}
```

### Step 5: Wire `--mcp` flag into the CLI

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
    Fastererer::MCP::Server.start
    return
  end
  # ... existing flow ...
end
```

### Step 6: Add tests

**New files:**
- `spec/lib/fastererer/mcp/server_spec.rb`
- `spec/lib/fastererer/mcp/tools/inspection_spec.rb`
- `spec/lib/fastererer/mcp/tools/list_checks_spec.rb`

**Test strategy:**
- Unit-test the tool handlers directly (they're just methods that take params and return data)
- Test the inspection tool with both `path` and `source_code` inputs
- Test that ignored speedups are filtered correctly
- Test error cases (missing file, invalid Ruby, both/neither params provided)
- Test the CLI flag parsing recognizes `--mcp`
- Do NOT test the stdio transport loop itself (that's the `mcp` gem's responsibility)

## Phase 2: Refinements

### Step 7: Refactor `Analyzer` to accept content directly

**File:** `lib/fastererer/analyzer.rb`

Currently `Analyzer.new(file_path)` reads the file in the constructor. For inline `source_code` support without a tempfile, add an alternative constructor:

```ruby
def initialize(file_path, content: nil)
  @file_path = file_path.to_s
  @file_content = content || File.read(file_path)
end
```

This lets the MCP inspection tool pass `source_code` directly:

```ruby
Analyzer.new('(inline)', content: source_code)
```

This is a backward-compatible change — existing callers don't pass `content:`.

### Step 8: Mark inspection tool as idempotent

Register the `fastererer_inspection` tool with the `readOnlyHint: true` annotation so MCP clients know it's safe to cache and retry.

The `fastererer_list_checks` tool should also be marked idempotent.

## File Structure (New Files)

```
lib/fastererer/
├── mcp/
│   ├── server.rb              # Server setup, gem loading, transport
│   └── tools/
│       ├── inspection.rb      # fastererer_inspection tool handler
│       └── list_checks.rb     # fastererer_list_checks tool handler
spec/lib/fastererer/
├── mcp/
│   ├── server_spec.rb
│   └── tools/
│       ├── inspection_spec.rb
│       └── list_checks_spec.rb
```

## Dependency Notes

- **`mcp` gem (~> 0.6):** Optional. Only loaded when `--mcp` is used. Not added to gemspec `add_dependency` to avoid forcing it on all users. Documented in README.
- **No other new dependencies.**
- **Ruby >= 3.3:** Already required; no change needed.

## Implementation Order

1. Steps 1-5 (core server, both tools, CLI flag) — can be done in a single PR
2. Step 6 (tests) — same PR as above
3. Steps 7-8 (Analyzer refactor, idempotent hints) — same PR or follow-up

The total implementation is approximately 200-300 lines of new Ruby code plus tests.

## Open Questions

1. **Tool naming:** Should tools be prefixed with `fastererer_` (e.g., `fastererer_inspection`) or use shorter names (e.g., `inspection`)? Prefixed names avoid collisions when multiple MCP servers are registered. RuboCop uses `rubocop_` prefix.
2. **Tempfile vs Analyzer refactor:** For `source_code` support, should we use a Tempfile (simpler, Phase 1) or refactor Analyzer immediately (cleaner, fewer moving parts)? The plan proposes Tempfile first, refactor second, but doing the refactor upfront is only a 2-line change.
3. **`mcp` gem version constraint:** The `mcp` gem is still pre-1.0. Should we pin `~> 0.6` (matching RuboCop) or use a looser constraint?
