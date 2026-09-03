# CLAUDE.md

This file provides guidance for writing specs in this directory. See the project root `CLAUDE.md`
for the commands used to run them, the coverage floors, and the conventions that apply everywhere.

## Layout

- Unit specs mirror `lib/`: `spec/lib/fastererer/<file>_spec.rb`. They parse source through
  `ParserHelpers#parse_first_statement` and build wrappers with `described_class.build(...)` or
  `described_class.new(...)`.
- Scenario specs live in `spec/lib/fastererer/analyzer/NN_<rule>_spec.rb` and run the analyzer over
  a fixture of the same number and name in `spec/support/analyzer/`. `.rubocop.yml` excludes that
  directory from `RSpec/SpecFilePathFormat` because the paths follow the scenario, not the class.
- **Assert the flagged line numbers, not just a count.** `expect(offending_lines).to
  contain_exactly(5, 34, 37)` fails when a scanner flags the wrong line; `expect(...count).to eq(3)`
  passes. Some older scenario specs still assert counts — prefer line numbers in new ones.

## Structure

- **Mirror the source file's method order.** `describe` / `context` blocks should appear in the same
  order as the methods they cover, so a spec can be read alongside its subject without jumping
  around. The mirror is keyed to the method's *current* position — when a review moves a method,
  re-check that its spec moved with it. A green spec written before the move stays where it was and
  silently drifts out of order.
- Tests for a nested class come after the primary class's method tests, in definition order.
- **Give each precondition its own `context`.** When a `describe` holds several examples that each
  set up different inputs or error scenarios, split them: one `context 'when …'` per precondition,
  shared setup in a `before` inside that context, and an `it` string that names only the resulting
  behavior — no "when" clause left in it.
- Use a maximum example group nesting of 4 levels. Several specs carry
  `# rubocop:disable RSpec/NestedGroups` where they exceed it; prefer restructuring over adding
  another disable.

## Style

- Don't stub the subject
- Use verified doubles (`instance_double`)
- Use single-line `let` statements and `before` blocks whenever they fit the 100-character RuboCop
  limit (e.g. `let(:offense) { described_class.new(:gsub_vs_tr, 12) }`, `before { analyzer.scan }`)
- Generally prefer fewer lines — avoid unnecessary multi-line blocks for simple expressions
- **Write variable names out in full.** Match what the surrounding file already uses; prefer
  `method_call` over `mc`, `offending_lines` over `lines`. Clarity beats brevity in test code.

## Coverage

`.simplecov` enforces 100% line *and* branch coverage over `lib/**/*.rb`, and only a whole-suite
run applies the floors. New code needs examples that reach every branch — a guard clause that is
never taken fails the build even when every line has run.
