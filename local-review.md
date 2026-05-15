# Local Review — add-rule-names-and-doc-links

**Review date:** 2026-05-15

## Review History

- **Initial review:** 2026-05-15
- **Reconcile:** 2026-05-15 — marked F1, F2, F10, F11, F20, F21, F22, F23, F24, F27 as fixed (commit `4dcd817` Tighten Explanation YAML loading and expand spec coverage)
- **Fix pass:** 2026-05-15 — F8, F9, F13, F14, F15 addressed

---

The PR is well-shaped: extracting `Explanation` as a YAML-backed value object is the right abstraction, `Offense` shrinks to a clean struct, and the rubocop-style output is a genuine UX improvement. The main concerns before merge are an eager-construction bug in `Offense#initialize` that wastes allocations (and is untested), a shallow-freeze that leaves the class-level rule cache mutable, and a missing completeness spec that verifies all 19 rules resolve. The security surface is narrow and approved; all security findings are defense-in-depth observations.

---

## Code Best Practices

### F1 ~~🟠 High - `Offense#initialize` eagerly constructs `Explanation`, defeating its own memoization~~ ✅ Fixed

**File:** `lib/fastererer/offense.rb:15`
**Status:** Fixed — `Offense#initialize` now calls the cheap `Explanation.validate!(offense_name)` class method instead of allocating an `Explanation`. The `#explanation` accessor still memoizes the per-offense instance via `@explanation ||= Explanation.new(offense_name)`.

`Offense#initialize` calls `explanation` to validate the rule, which also builds and caches the `Explanation` instance. Every `Offense` (potentially thousands) now allocates an `Explanation` whose `description`/`url` are only needed at output time — and `FileTraverser#output` builds its own `Explanation.new(error_group_name)` per group anyway, so the per-`Offense` instance is allocated and discarded. Commit to one path: either validate cheaply without caching, or cache and have `FileTraverser` reuse it.

Cheap-validation route (smaller change):

```ruby
def initialize(offense_name, line_number)
  @offense_name = offense_name
  @line_number  = line_number
  Explanation.fetch!(offense_name) # raises UnknownRuleError if absent
end

def explanation
  @explanation ||= Explanation.new(offense_name)
end
```

### F2 ~~🟠 High - `Explanation.rules` swallows file-missing / malformed YAML with confusing errors~~ ✅ Fixed

**File:** `lib/fastererer/explanation.rb:12-14`
**Status:** Fixed — `load_rules` now raises an explicit `RuntimeError` if `en.fastererer.rules` is missing/malformed (line 24-26) and rescues `Errno::ENOENT` to a clearer message (line 29-30).

Three failure modes are silent or misleading: (1) missing file → bare `Errno::ENOENT` deep in a private internal; (2) typo'd nested keys → `dig` returns `nil`, `@rules ||= nil` retries on every call, then blows up with `NoMethodError: undefined method 'fetch' for nil`; (3) once set, `@rules` is frozen but never revalidated.

```ruby
def self.rules
  @rules ||= load_rules
end

def self.load_rules
  data = YAML.safe_load_file(LOCALE_PATH).dig('en', 'fastererer', 'rules')
  raise "Fastererer locale at #{LOCALE_PATH} is missing 'en.fastererer.rules'" unless data.is_a?(Hash)

  data.freeze
rescue Errno::ENOENT
  raise "Fastererer locale file not found at #{LOCALE_PATH}"
end
```

### F3 🟡 Medium - PascalCase derivation lives in the wrong abstraction

**File:** `lib/fastererer/explanation.rb:33-45`

`Explanation` is a data-loading value object; deriving a rule display name from a snake_case key is a string transformation unrelated to locale loading. The hardcoded `DEPARTMENT = 'Performance'` on the `Explanation` class reinforces this — `Explanation` doesn't have a department, rules do. Options: (a) move `rule_name` into the YAML (most i18n-aligned); (b) move derivation to a small helper like `RuleName.from(symbol)`.

### F4 🟡 Medium - `UnknownRuleError` is nested under `Explanation` but triggered via `Offense.new`

**File:** `lib/fastererer/explanation.rb:10`, `lib/fastererer/offense.rb:15`

Callers rescuing this error must write `rescue Fastererer::Explanation::UnknownRuleError` even though they never interacted with `Explanation` directly. Hoist to `Fastererer::UnknownRuleError` or `Fastererer::Offense::UnknownRuleError`.

### F5 🟡 Medium - `FileTraverser#output` re-instantiates `Explanation` per group even though each `Offense` already has one

**File:** `lib/fastererer/file_traverser.rb:87-92`

`error_occurences` is `[Offense, …]` and each `Offense` exposes `#explanation`. If the cached `explanation` on `Offense` is kept (see F1), pull it from the first element: `explanation = error_occurences.first.explanation`. If not, `Offense#explanation` becomes dead code and should be removed. Pick one path.

### F6 🟡 Medium - `Painter.paint('W', :magenta)` is a literal recomputed on every `output` call

**File:** `lib/fastererer/file_traverser.rb:85`, `lib/fastererer/painter.rb:8`

The `'W'`/`:magenta` pairing is invariant. Encapsulate as `Painter.severity('W')` or freeze a constant: `SEVERITY = Painter.paint('W', :magenta).freeze` at the top of `FileTraverser`.

### F7 🟢 Low - `@rules` class memoization is process-global and unresettable

**File:** `lib/fastererer/explanation.rb:12`

Once any test instantiates `Explanation`, the frozen hash is locked in for the entire process. Add a test-only reset hook:

```ruby
private_class_method def self.reset! = @rules = nil
```

### F8 ~~🟢 Low - `to_s` appends `.` even if `description` already ends in one~~ ✅ Fixed

**File:** `lib/fastererer/explanation.rb:38`
**Status:** Fixed — `to_s` now calls `description.delete_suffix('.')` before re-appending the period (line 60). Rubocop's `Performance/DeleteSuffix` cop steered us to `delete_suffix` instead of `sub(/\.\z/, '')` — a non-regex string op fits this gem's perf ethos. Spec added at `spec/lib/fastererer/explanation_spec.rb` covers a description that ends with a period.

`"#{rule_name}: #{description}. (#{url})"` produces `"…faster.. (url)"` if the description ends with a period. Either strip or document the convention:

```ruby
"#{rule_name}: #{description.sub(/\.\z/, '')}. (#{url})"
```

### F9 ~~🟢 Low - `Explanation#initialize` accepts symbol or string but lookups always coerce to string~~ ✅ Fixed

**File:** `lib/fastererer/explanation.rb:18-23`
**Status:** Fixed — `Explanation#initialize` now normalizes via `@offense_name = offense_name.to_sym` (line 43). Spec added asserting `described_class.new('for_loop_vs_each').offense_name == :for_loop_vs_each`.

`@offense_name` is stored as-passed while lookups always call `to_s`. Normalize once at construction: `@offense_name = offense_name.to_sym`.

---

## Ruby / Gem Expert

### F10 ~~🟠 High - `YAML.safe_load_file(...).freeze` is a shallow freeze — inner hashes remain mutable~~ ✅ Fixed

**File:** `lib/fastererer/explanation.rb:13`
**Status:** Fixed — `load_rules` now deep-freezes via `data.transform_values { |row| row.transform_values(&:freeze).freeze }.freeze` (line 28). Inner hashes and string values are all frozen, eliminating the class-level cache poisoning vector.

`freeze` only freezes the outer hash. Each rule's `{'description'=>..., 'url'=>...}` hash and each string inside it remains mutable. A caller doing `Explanation.new(:gsub_vs_tr).description << 'oops'` would mutate the class-level cache and poison every subsequent instance.

```ruby
def self.load_rules
  YAML.safe_load_file(LOCALE_PATH)
      .dig('en', 'fastererer', 'rules')
      .transform_values { |row| row.transform_values(&:freeze).freeze }
      .freeze
end
```

### F11 ~~🟡 Medium - Eager YAML load at first `Offense.new` with confusing failure surface~~ ✅ Fixed

**File:** `lib/fastererer/explanation.rb:13`
**Status:** Fixed via F2 — the confusing failure surface is no longer confusing. Both the missing-file and missing-section failure modes now raise descriptive messages from `load_rules`. The "eager-load at gem boot" half remains an optional future enhancement, not a blocker.

If `config/locales/en.yml` is missing or malformed, the error surfaces as `Errno::ENOENT` or `Psych::SyntaxError` inside `Offense.new`. Two improvements: (1) eager-load at gem boot so packaging errors fail immediately; (2) wrap with a clearer message. (Overlaps with F2 — address together.)

### F12 🟡 Medium - i18n shape is aspirational, not load-bearing

**File:** `lib/fastererer/explanation.rb:1-47`

URLs are not translatable — they point to a single upstream English doc. Nesting them under `en.fastererer.rules` falsely implies they could be localized. Consider `config/rules.yml` for keys/URLs and `config/locales/en.yml` for descriptions only. Not blocking — flagging so it is a conscious choice.

### F13 ~~🟢 Low - `String#split('_').map(&:capitalize).join` silently collapses doubled underscores~~ ✅ Fixed

**File:** `lib/fastererer/explanation.rb:43-45`
**Status:** Fixed — `pascal_case` now uses `filter_map { |part| part.capitalize unless part.empty? }` (line 67) so empty parts from doubled (or leading) underscores are skipped explicitly. Spec asserts `pascal_case(:foo__bar) == 'FooBar'`.

`"foo__bar".split('_')` produces `["foo", "", "bar"]`; `"".capitalize` is `""`, so the double underscore collapses. Add a 1-line spec or use `filter_map { |part| part.capitalize unless part.empty? }`.

### F14 ~~🟢 Low - `@data` ivar name is generic~~ ✅ Fixed

**File:** `lib/fastererer/explanation.rb:18-23`
**Status:** Fixed — `@data` renamed to `@row` and exposed via a private `attr_reader :row` (line 64), so `description`/`url` become `row.fetch('description')` / `row.fetch('url')`.

`@data` is opaque. Consider `@row` or `@rule_data` with `attr_reader` so `description`/`url` become one-liners.

### F15 ~~🟢 Low - `Explanation.new` is called once per offense group but not memoized across files~~ ✅ Fixed

**File:** `lib/fastererer/file_traverser.rb:84-93`
**Status:** Fixed — `Explanation.for(offense_name)` flyweight added (line 16-19) and `FileTraverser#output` now calls it instead of `Explanation.new` (line 88). Cache key is normalized via `to_sym` so symbol/string callers share the entry. Spec covers identity, symbol/string sharing, and unknown-rule failure. Note: this addresses cross-file de-duplication but does not reconcile F5 (per-group re-instantiation vs reusing `Offense#explanation`) — that tension remains open.

For 100 files all hitting the same rule, 100 `Explanation` objects are allocated. They are cheap, but a future maintainer may not know that. Optional flyweight:

```ruby
def self.for(offense_name)
  @cache ||= {}
  @cache[offense_name] ||= new(offense_name)
end
```

### F16 🟢 Low - `Offense#explanation` return type changed from String to `Fastererer::Explanation`

**File:** `lib/fastererer/offense.rb:15`

Previously a `String`, now an `Explanation` instance. Any external consumer doing `offense.explanation == "Some text"` will silently get `false`. Add a CHANGELOG note, or preserve the previous String return and add a separate `Offense#explanation_object`.

### F17 🟢 Low - Descriptions inconsistently end with periods

**File:** `config/locales/en.yml:35,47`

The `to_s` format relies on descriptions not ending in punctuation (see F8). Add a spec that enforces this convention:

```ruby
it 'descriptions do not end with terminal punctuation' do
  described_class.rules.each_value do |row|
    expect(row['description']).not_to match(/[.!?]\z/)
  end
end
```

---

## Security

### F18 🟢 Low - Terminal control character injection (defense-in-depth)

**File:** `lib/fastererer/file_traverser.rb:90`, `lib/fastererer/explanation.rb:36`

If a future contributor puts ESC/CSI/OSC bytes into a description, those would be emitted verbatim to the terminal. Today's `en.yml` is printable ASCII, so this is a supply-chain hygiene concern only. Lowest-overhead fix: add a spec asserting every `description`/`url` matches `/\A[[:print:][:space:]]+\z/`.

### F19 🟢 Low - URL scheme validation (defense-in-depth)

**File:** `lib/fastererer/explanation.rb:24`

`url` is read verbatim and printed. If a future entry used `javascript:` or `data:`, some terminals would auto-linkify it. Validate at load time:

```ruby
data.each_value do |v|
  raise "Invalid URL: #{v['url']}" unless v['url'].start_with?('https://')
end
```

---

## Test Coverage

### F20 ~~🔴 Critical - Missing YAML completeness test (all 19 rules load and resolve)~~ ✅ Fixed

**File:** `spec/lib/fastererer/explanation_spec.rb`
**Status:** Fixed — the new "rule catalog" describe block (lines 88-111) asserts the catalog contains exactly 19 rules, each rule has a non-empty String description, and each URL starts with `https://github.com/fastruby/fast-ruby#`.

The spec only sanity-checks 3 keys. The previous `EXPLANATIONS` constant was source-grep-friendly; the YAML is not. A missing or miskeyed entry now fails silently at runtime rather than at load time. Add a completeness spec:

```ruby
describe 'rule coverage' do
  Fastererer::Offense::OFFENSES.each do |key|
    it "has a complete YAML entry for #{key}" do
      explanation = described_class.new(key)
      expect(explanation.description).to be_a(String).and(be_present)
      expect(explanation.url).to start_with('https://github.com/fastruby/fast-ruby#')
    end
  end
end
```

If `Offense::OFFENSES` does not exist, fall back to `described_class.rules.keys.map(&:to_sym)` and assert size == 19.

### F21 ~~🟠 High - `Offense#initialize` eager-validation is untested~~ ✅ Fixed

**File:** `spec/lib/fastererer/offense_spec.rb`
**Status:** Fixed — `spec/lib/fastererer/offense_spec.rb` now exists with three `#initialize` cases (raises `UnknownRuleError` on unknown rule, stores `offense_name`, stores `line_number`) and three `#explanation` cases (returns an `Explanation`, matches `offense_name`, memoizes).

The only invariant `Offense` enforces — rejecting unknown rule names — has zero coverage.

```ruby
describe Fastererer::Offense do
  describe '#initialize' do
    it 'raises UnknownRuleError when offense_name is unknown' do
      expect { described_class.new(:no_such_rule, 1) }
        .to raise_error(Fastererer::Explanation::UnknownRuleError)
    end

    it 'memoizes the Explanation' do
      offense = described_class.new(:for_loop_vs_each, 1)
      expect(offense.explanation).to be(offense.explanation)
    end
  end
end
```

### F22 ~~🟠 High - `FileTraverser` output spec covers only one offense / one rule type~~ ✅ Fixed

**File:** `spec/lib/fastererer/file_traverser_spec.rb:328-336`
**Status:** Fixed — a second `context 'with multiple rule types in one file'` (lines 338-347) uses `multiple_offenses.rb` fixture and asserts both `Performance/ForLoopVsEach:` and `Performance/ShuffleFirstVsSample:` appear in the output.

Add a second context with a fixture triggering two distinct rules to verify grouping and multi-line printing.

### F23 ~~🟠 High - Class-memoized `@rules` is shared across tests (load-order coupling)~~ ✅ Fixed

**File:** `lib/fastererer/explanation.rb:11-13`
**Status:** Fixed — `explanation_spec.rb` now includes a `.rules` describe block (lines 65-86) with four guard specs verifying that repeated calls return the same object, the top-level hash is frozen, every row hash is frozen, and every description/url string is frozen. The `reset!` hook from F7 is not yet wired but the guard spec — the "at minimum" requirement of this finding — is in place.

Tests that stub the YAML path receive the cached value. At minimum, add a guard spec:

```ruby
describe '.rules' do
  it 'returns the same frozen hash on repeated calls' do
    expect(described_class.rules).to be(described_class.rules)
    expect(described_class.rules).to be_frozen
  end
end
```

If stubbing is ever needed, wire the `reset!` hook from F7.

### F24 ~~🟡 Medium - `UnknownRuleError` message format is not pinned~~ ✅ Fixed

**File:** `spec/lib/fastererer/explanation_spec.rb:48-51`
**Status:** Fixed — the matcher is now tightened to `.to raise_error(described_class::UnknownRuleError, /Unknown rule: :no_such_rule/)` (line 50), and a sibling test on `.validate!` (line 60-61) pins the same regex for the underlying class method.

`/no_such_rule/` only verifies the key appears in the message. A regression to `to_s` would still pass. Tighten:

```ruby
.to raise_error(described_class::UnknownRuleError, /Unknown rule: :no_such_rule/)
```

### F25 🟡 Medium - No coverage for YAML load failure modes

**File:** `spec/lib/fastererer/explanation_spec.rb`

Missing file → `Errno::ENOENT`; structural change → `dig` returns `nil`, every `Explanation.new` raises `NoMethodError: undefined method 'fetch' for nil`. Add a guard in `.rules` (addresses F2) and cover both failure modes with a spec.

### F26 🟡 Medium - Hardcoded ANSI escapes in `FileTraverser` output spec are brittle

**File:** `spec/lib/fastererer/file_traverser_spec.rb:332`

`"\e[31m...\e[0m: \e[35mW\e[0m"` couples the spec to `Painter` internals. Replace with `Painter.paint` calls:

```ruby
it 'prints offense' do
  red_path = Fastererer::Painter.paint("#{test_file_path}:1", :red)
  severity = Fastererer::Painter.paint('W', :magenta)
  match = "#{red_path}: #{severity}: #{explanation}\n\n"
  expect { file_traverser.send(:output, analyzer) }.to output(match).to_stdout
end
```

### F27 ~~🟡 Medium - `Painter` behavior with an unknown color symbol is undefined and untested~~ ✅ Fixed

**File:** `lib/fastererer/painter.rb`
**Status:** Fixed in code — `Painter.paint` now raises `ArgumentError` with a descriptive message when given an unknown color symbol (lines 12-16). The remaining "untested" sub-claim is captured by F28 (the missing painter spec file).

`COLOR_CODES[color]` returns `nil` for an unknown symbol, producing `"\e[m...\e[0m"`. Raise or use `fetch`, and cover with a spec.

### F28 🟢 Low - `Painter` has no spec file

**File:** `spec/lib/fastererer/painter_spec.rb` (does not exist)

Even a 5-line spec would have caught the issues behind F26 and F27.

### F29 🟢 Low - `to_s` URL edge case: parentheses in URLs

**File:** `lib/fastererer/explanation.rb:38`

If a future URL contains `)`, output becomes ambiguous. Add a regression spec asserting current URLs are paren-free.

---

## Consolidated Summary

| Finding | Priority | Category | Description | File | Status |
|---------|----------|----------|-------------|------|--------|
| F1 | 🟠 High | Code Quality | `Offense#initialize` eagerly constructs `Explanation`, defeating memoization | `offense.rb:15` | ✅ |
| F2 | 🟠 High | Code Quality | `Explanation.rules` swallows file-missing / malformed YAML with confusing errors | `explanation.rb:12-14` | ✅ |
| F3 | 🟡 Medium | Code Quality | PascalCase derivation lives in the wrong abstraction | `explanation.rb:33-45` | — |
| F4 | 🟡 Medium | Code Quality | `UnknownRuleError` nested under `Explanation` but triggered via `Offense.new` | `explanation.rb:10` | — |
| F5 | 🟡 Medium | Code Quality | `FileTraverser#output` re-instantiates `Explanation` per group unnecessarily | `file_traverser.rb:87-92` | — |
| F6 | 🟡 Medium | Performance | `Painter.paint('W', :magenta)` recomputed on every `output` call | `file_traverser.rb:85` | — |
| F7 | 🟢 Low | Testing | `@rules` class memoization is unresettable in test suite | `explanation.rb:12` | — |
| F8 | 🟢 Low | Code Quality | `to_s` appends `.` even if description already ends in one | `explanation.rb:38` | ✅ |
| F9 | 🟢 Low | Code Quality | `Explanation#initialize` accepts symbol or string but coerces inconsistently | `explanation.rb:18-23` | ✅ |
| F10 | 🟠 High | Code Quality | Shallow freeze leaves inner rule hashes mutable | `explanation.rb:13` | ✅ |
| F11 | 🟡 Medium | Code Quality | Eager YAML load at first `Offense.new` with confusing failure surface | `explanation.rb:13` | ✅ |
| F12 | 🟡 Medium | Design | i18n shape is aspirational — URLs cannot be localized | `explanation.rb:1-47` | — |
| F13 | 🟢 Low | Code Quality | `split('_').map(&:capitalize)` silently collapses doubled underscores | `explanation.rb:43-45` | ✅ |
| F14 | 🟢 Low | Code Quality | `@data` ivar name is generic | `explanation.rb:18-23` | ✅ |
| F15 | 🟢 Low | Performance | `Explanation.new` not memoized across files for the same rule | `file_traverser.rb:84-93` | ✅ |
| F16 | 🟢 Low | API | `Offense#explanation` return type changed from String to `Explanation` instance | `offense.rb:15` | — |
| F17 | 🟢 Low | Code Quality | Descriptions inconsistently end with periods — no enforcing spec | `config/locales/en.yml:35,47` | — |
| F18 | 🟢 Low | Security | Terminal control character injection (defense-in-depth) | `file_traverser.rb:90` | — |
| F19 | 🟢 Low | Security | URL scheme not validated at load time (defense-in-depth) | `explanation.rb:24` | — |
| F20 | 🔴 Critical | Testing | Missing YAML completeness test — all 19 rules load and resolve | `explanation_spec.rb` | ✅ |
| F21 | 🟠 High | Testing | `Offense#initialize` eager-validation is untested | `offense_spec.rb` | ✅ |
| F22 | 🟠 High | Testing | `FileTraverser` output spec covers only one rule type | `file_traverser_spec.rb:328-336` | ✅ |
| F23 | 🟠 High | Testing | Class-memoized `@rules` shared across tests (load-order coupling) | `explanation.rb:11-13` | ✅ |
| F24 | 🟡 Medium | Testing | `UnknownRuleError` message format not pinned in spec | `explanation_spec.rb:48-51` | ✅ |
| F25 | 🟡 Medium | Testing | No coverage for YAML load failure modes | `explanation_spec.rb` | — |
| F26 | 🟡 Medium | Testing | Hardcoded ANSI escapes in `FileTraverser` spec are brittle | `file_traverser_spec.rb:332` | — |
| F27 | 🟡 Medium | Testing | `Painter` behavior with unknown color symbol is undefined and untested | `painter.rb` | ✅ |
| F28 | 🟢 Low | Testing | `Painter` has no spec file | `painter_spec.rb` (missing) | — |
| F29 | 🟢 Low | Testing | `to_s` URL parenthesis edge case uncovered | `explanation.rb:38` | — |
| F30 | ℹ️ Observation | Testing | `explanation_spec.rb` complies with project conventions | `explanation_spec.rb` | — |
| F31 | ℹ️ Observation | Security | `YAML.safe_load_file` with Psych ≥ 4 defaults — deserialization is clean | `explanation.rb:12` | — |
| F32 | ℹ️ Observation | Security | `LOCALE_PATH` uses `File.expand_path(__dir__)` — no user input, no traversal risk | `explanation.rb:7` | — |
| F33 | ℹ️ Observation | Security | Printed URLs are displayed as text, not fetched — no SSRF | `file_traverser.rb:90` | — |
| F34 | ℹ️ Observation | Code Quality | `Offense` shrinks from ~67 lines to a clean ~22-line struct | `offense.rb` | — |
| F35 | ℹ️ Observation | Testing | Stale `EXPLANATIONS` constant references — grep returns nothing; removal is clean | codebase | — |
| F36 | ℹ️ Observation | Code Quality | `config/locales/en.yml` path resolves correctly in both source checkout and installed gem | `explanation.rb:7` | — |
| F37 | ℹ️ Observation | Testing | `file_traverser_spec.rb:329-335` assertion coupling to `Explanation#to_s` is intentional | `file_traverser_spec.rb` | — |
| F38 | ℹ️ Observation | Code Quality | `:magenta` added to `Painter` with integration spec coverage via `\e[35m` | `painter.rb:8` | — |

---

## Pre-Merge Checklist

- [x] F20 — Add YAML completeness spec verifying all 19 rules load and resolve (fixed) ✅
- [x] F1 — Resolve eager-construction / memoization conflict in `Offense#initialize` (fixed) ✅
- [x] F2 — Add error-handling in `Explanation.rules` for missing file and malformed YAML (fixed) ✅
- [x] F10 — Deep-freeze inner rule hashes in `Explanation.load_rules` (fixed) ✅
- [x] F21 — Add `offense_spec.rb` covering `UnknownRuleError` on unknown rule names (fixed) ✅
- [x] F22 — Extend `FileTraverser` output spec to cover two distinct rule types (fixed) ✅
- [x] F23 — Add `.rules` frozen/identity spec; wire `reset!` hook if YAML stubbing is needed (fixed — guard spec landed) ✅
- [ ] F3 — Move PascalCase derivation and `DEPARTMENT` out of `Explanation`
- [ ] F4 — Hoist `UnknownRuleError` to `Fastererer::UnknownRuleError`
- [ ] F5 — Reconcile `FileTraverser` re-instantiation with `Offense#explanation` (remove one or use the other)
- [ ] F6 — Freeze the `'W'`/`:magenta` painted constant instead of recomputing per call
- [x] F11 — Wrap YAML load failure with a clear gem-level message (fixed via F2) ✅
- [ ] F12 — Decide consciously whether URLs belong in the i18n locale or a separate config
- [x] F24 — Tighten `UnknownRuleError` message matcher to `/Unknown rule: :no_such_rule/` (fixed) ✅
- [ ] F25 — Add specs for missing-file and malformed-YAML failure modes
- [ ] F26 — Replace hardcoded ANSI escapes in `FileTraverser` spec with `Painter.paint` calls
- [x] F27 — Raise (or `fetch`) on unknown color symbol in `Painter`; add spec (fixed in code — spec covered by F28) ✅
- [ ] F7 — Add `Explanation.reset!` test hook
- [x] F8 — Strip trailing `.` from description before appending period in `to_s` (fixed — `delete_suffix`) ✅
- [x] F9 — Normalize `@offense_name` to symbol at construction (fixed) ✅
- [x] F13 — Guard against doubled underscores in PascalCase derivation (fixed — `filter_map`) ✅
- [x] F14 — Rename `@data` to `@row` or `@rule_data` (fixed — `@row` with private `attr_reader`) ✅
- [x] F15 — Consider flyweight `Explanation.for(offense_name)` if `FileTraverser` keeps re-instantiating (fixed) ✅
- [ ] F16 — Add CHANGELOG note for `Offense#explanation` type change (String → `Explanation`)
- [ ] F17 — Add spec enforcing descriptions do not end with terminal punctuation
- [ ] F18 — Add spec asserting all descriptions/URLs match `/\A[[:print:][:space:]]+\z/`
- [ ] F19 — Validate URL schemes start with `https://` at load time
- [ ] F28 — Create `spec/lib/fastererer/painter_spec.rb`
- [ ] F29 — Add regression spec asserting current URLs contain no closing parentheses

---

## Positive Feedback

- **F30** — `spec/lib/fastererer/explanation_spec.rb` fully complies with project conventions: ≤ 4 nesting levels, ≤ 100 character line length, single-line `let` blocks, and no stubs on the subject.
- **F31** — `YAML.safe_load_file` with Psych ≥ 4 defaults restricts permitted classes and disables aliases. The bundled `en.yml` contains only strings and maps. No deserialization risk.
- **F32** — `LOCALE_PATH = File.expand_path('../../config/locales/en.yml', __dir__)` involves no user input and no interpolation. Safe under both vendored-bundle and system-gem installs.
- **F33** — URLs from the YAML are displayed as text strings in the terminal, not fetched. No SSRF or auto-open risk.
- **F34** — `Offense` shrinks from approximately 67 lines (with an inline `EXPLANATIONS` constant) to a clean ~22-line struct. The value object extraction is well-motivated and the right shape.
- **F35** — The `EXPLANATIONS` constant has been fully removed. A grep of the codebase returns nothing; the removal is clean.
- **F36** — `File.expand_path('../../config/locales/en.yml', __dir__)` resolves correctly in both source checkouts and installed gems. No change needed for gem packaging.
- **F37** — The `file_traverser_spec.rb:329-335` assertion couples to `Explanation#to_s`, which is intentional — it tests the integrated output format end-to-end.
- **F38** — `:magenta` is added to `Painter` without a dedicated unit spec, but integration coverage via the `\e[35m` escape in `file_traverser_spec.rb` provides confidence.
