# Local Review — native-prism-migration branch

**Date:** 2026-05-14
**Branch:** `native-prism-migration`
**Commit:** `11cb6f6 Migrate from ruby_parser to native Prism AST`
**Base:** `main`

## Summary

This commit replaces `ruby_parser` with the official Prism gem, adopts
`Prism::Visitor` for AST traversal, and rewrites node-type dispatch throughout
the codebase. The migration is architecturally sound and the core visitor
pattern is a genuine improvement over the old hand-rolled traversal. The main
risks are a behavioral regression in block-argument collection (affecting the
symbol-to-proc check), two clusters of dead code around `BlockArgument` and
`visit_lambda_node`, and an over-broad `rescue StandardError` that silently
reclassifies real bugs as parse errors. Address F1–F4 before merging.

## Findings

### F1 🟠 High Priority — `scan_file` swallows every `StandardError` as a parse error

**Reviewer(s):** Code Best Practices, Security
**File:** `lib/fastererer/file_traverser.rb` (line 59)
**Issue:** The previous implementation caught a narrow allow-list of
parser-specific exceptions. The new code rescues `StandardError`, which means a
`NoMethodError` from a buggy scanner, an `Errno::EACCES` on file read, or any
other programming error is silently reclassified as "the internal parser is not
able to read some characters or has timed out." Real bugs pass review unnoticed.
Additionally, the user-facing message on lines 103–105 claims a timeout as a
possible cause, but no `Timeout.timeout` call exists anywhere in the codebase
after this migration.

**Fix:**

```ruby
rescue Fastererer::ParseError, Errno::ENOENT => e
  parse_error_paths.push(ErrorData.new(path, e.class, e.message).to_s)
```

Also update `output_parse_errors` to drop "or has timed out" from the message.

---

### F2 🟠 High Priority — `set_block_argument_names` silently drops optional, keyword, splat, and rest block params

**Reviewer(s):** Code Best Practices, Ruby Idiom, Test Coverage
**File:** `lib/fastererer/method_call.rb` (line 72)
**Issue:** `set_block_argument_names` reads only `params.parameters.requireds`.
For any block with optional, keyword, splat, or rest parameters — e.g.,
`arr.map { |x = 1| x }` or `arr.map { |x:| x }` — `requireds` is empty, so
`block_argument_names.one?` is false in `SymbolToProcCheck#symbol_to_proc_candidate?`
and the offense never fires. This is a behavioral regression from the old
implementation.

Additionally, a destructuring block param (`Prism::MultiTargetNode`) does not
respond to `.name`; if one reaches `symbol_to_proc_body?`, the comparison at
`body_call.receiver.name == method_call.block_argument_names.first` could
`NoMethodError`. The fix is to collect all names safely, then let
`symbol_to_proc_candidate?` filter on required-only count if needed.

**Fix:**

```ruby
def set_block_argument_names
  block = element.block
  return @block_argument_names = [] unless block.is_a?(Prism::BlockNode)

  params = block.parameters
  unless params.is_a?(Prism::BlockParametersNode) && params.parameters
    return @block_argument_names = []
  end

  p = params.parameters
  all = p.requireds + p.optionals + Array(p.rest) + p.posts +
        p.keywords + Array(p.keyword_rest) + Array(p.block)
  @block_argument_names = all.filter_map { |n| n.name if n.respond_to?(:name) }
end
```

No specs pin the behavior for non-required block params; add them before or
alongside the fix.

---

### F3 🟠 High Priority — Multi-error parse results silently discard all but the first error

**Reviewer(s):** Test Coverage
**File:** `lib/fastererer/analyzer.rb` (lines 28–31)
**Issue:** `Analyzer#scan` does `error = result.errors.first` and raises only
that one. Subsequent Prism errors are silently discarded. None of the three
parse-error specs in `analyzer_parse_error_spec.rb` feeds input that produces
multiple Prism errors, so the behavior is untested.

`ParseError` is defined as a plain `StandardError` subclass with no structured
access to Prism error objects, which also discards `.location` and `.level` info
that Prism provides per error.

**Fix:**

```ruby
class ParseError < StandardError
  attr_reader :prism_errors
  def initialize(errors)
    @prism_errors = errors
    super(errors.map(&:message).join('; '))
  end
end

# In Analyzer#scan:
raise Fastererer::ParseError.new(result.errors) if result.failure?
```

Add a spec that supplies multiple-error input and asserts all messages appear.

---

### F4 🟡 Medium Priority — `BlockArgument` and the `:block_pass` `ArgumentFactory` branch are unreachable dead code

**Reviewer(s):** Test Coverage, Ruby Idiom
**Files:** `lib/fastererer/method_call.rb` (line 133, lines 113–121, lines 154–158)
**Issue:** Prism places `&:sym` on `element.block` (as a `BlockArgumentNode`),
not inside `element.arguments&.arguments`. Because `set_arguments` iterates
only `element.arguments&.arguments`, `ArgumentFactory.build` never receives a
`BlockArgumentNode`. The `when Prism::BlockArgumentNode` branch in
`ArgumentFactory` and the `Prism::BlockArgumentNode => :block_pass` entry in
`TYPE_BY_NODE_CLASS` are therefore unreachable through the normal `MethodCall`
path. The only spec for `BlockArgument` constructs the node directly via
`Prism.parse(...)...block` (line 568), bypassing `ArgumentFactory` entirely —
confirming the dead-code path.

**Fix options:**

- (a) Delete `BlockArgument`, the `ArgumentFactory` branch for it, and the
  `Prism::BlockArgumentNode => :block_pass` hash entry as dead code, or
- (b) Teach `set_arguments` to also include `element.block` when it is a
  `BlockArgumentNode`.

Also change the spec at line 568 to use `Fastererer::Parser.parse(...)` for
consistency.

---

### F5 🟡 Medium Priority — `Parser.parse` leaks `Prism::ParseResult` to every caller

**Reviewer(s):** Ruby Idiom, Test Coverage
**File:** `lib/fastererer/parser.rb` (line 10)
**Issue:** `Parser` is documented as "a stable internal API and a single seam
for testing or future parser changes," but it returns a raw `Prism::ParseResult`
object. Every caller — `Analyzer#scan` and 15+ specs — must know about
`.failure?`, `.errors`, `.value`, `.statements.body.first`. Swapping parsers
requires changes at every call site, defeating the abstraction's stated purpose.
The brittle `parsed.value.statements.body.first` chain is repeated across 20+
spec locations; if Prism renames any of these methods, dozens of specs break.

**Fix:** Raise on failure and return the AST root from `Parser.parse`:

```ruby
def self.parse(ruby_code)
  result = Prism.parse(ruby_code)
  raise Fastererer::ParseError, result.errors.first.message if result.failure?
  result.value
end
```

This simplifies `Analyzer#scan` (no `result.failure?` check needed) and makes
`Parser` the single place that understands Prism's result shape. Extract a
spec helper for the remaining navigational boilerplate:

```ruby
# spec_helper.rb
module ParserHelpers
  def parse_first_statement(code)
    Fastererer::Parser.parse(code).statements.body.first
  end
end
RSpec.configure { |c| c.include ParserHelpers }
```

Note: adopting this fix would also resolve F3, since error handling consolidates
inside `Parser`.

---

### F6 🟡 Medium Priority — `MethodDefinition#set_arguments` silently drops rest, post, keyword-rest, and block params

**Reviewer(s):** Code Best Practices, Ruby Idiom, Test Coverage
**File:** `lib/fastererer/method_definition.rb` (line 44)
**Issue:** `params.requireds + params.optionals + params.keywords` omits
`params.rest` (`*splat`), `params.posts` (post-splat positionals),
`params.keyword_rest` (`**opts`), and `params.block`. The public
`attr_reader :arguments` advertises "all arguments," which is misleading.
The fixture `method_with_splat_and_block.rb` is only exercised for `block?`
and `block_argument_name` — no spec asserts argument count or that the splat
is absent.

**Fix:** Include all param categories, or rename the reader to reflect its
actual scope (e.g., `named_arguments`). At minimum, add specs that pin the
current behavior so any future change is visible.

---

### F7 🟡 Medium Priority — `visit_lambda_node` dispatches to `scan_method_calls` but performs no useful work

**Reviewer(s):** Ruby Idiom
**File:** `lib/fastererer/analyzer.rb` (line 90)
**Issue:** `visit_lambda_node` calls `scan_method_calls(node)`, which builds
`MethodCall.new(lambda_node)`. The constructor detects `lambda_literal?`, calls
`set_lambda_defaults`, and returns. No checker handles `:lambda` and
`SymbolToProcCheck#symbol_to_proc_candidate?` explicitly bails on
`lambda_literal?`. Every lambda in scanned code therefore allocates a
`MethodCallScanner`, a `MethodCall`, and empty arrays — to do nothing. The
default `Prism::Visitor` already descends into the lambda body via `super`, so
call-nodes inside the lambda body are still visited through `visit_call_node`.

**Fix:** Remove `visit_lambda_node` from `AnalyzerVisitor`. The corresponding
spec in `analyzer_visitor_spec.rb` (lines 53–62) should be deleted.

---

### F8 🟡 Medium Priority — `Analyzer` exposes four internal callbacks as public API to serve its own sibling class

**Reviewer(s):** Code Best Practices
**File:** `lib/fastererer/analyzer.rb` (lines 41–61)
**Issue:** `AnalyzerVisitor` lives in the same file and exists solely to
dispatch back into `Analyzer`. Because Prism's `Visitor` requires a separate
class, `scan_method_definitions`, `scan_method_calls`, `scan_for_loop`, and
`scan_rescue` had to be promoted to public API. A comment now apologizes for
it. Any external code can call `Analyzer.new(path).scan_method_calls(some_node)`
and it will compile.

**Fix options:**

- (a) Mark `AnalyzerVisitor` as a `private_constant` nested inside `Analyzer`
  and access private methods via `__send__`.
- (b) Flip the relationship: move scanning logic directly into the visitor,
  making `Analyzer` a thin orchestrator. This better fits the visitor pattern
  and eliminates the need to expose anything beyond `scan` and `errors`.

---

### F9 🟡 Medium Priority — `set_*` mutator pattern adds initialization complexity for no benefit

**Reviewer(s):** Code Best Practices, Ruby Idiom
**Files:** `lib/fastererer/method_call.rb` (lines 34–73), `lib/fastererer/method_definition.rb` (lines 27–53), `lib/fastererer/rescue_call.rb` (line 15)
**Issue:** Java-style imperative initialization runs all `set_*` methods eagerly
even when most attributes are never read by a scanner. The `set_arguments`
mutator that writes `@arguments = []` in multiple branches obscures control
flow. Each `set_*` method is a private void procedure that can only be called
from `initialize`, so they are neither reusable nor independently testable.

**Fix:** Replace with memoized readers:

```ruby
def receiver = @receiver ||= ReceiverFactory.build(element.receiver)
def method_name = element.name
def arguments
  @arguments ||= (element.arguments&.arguments || []).map { |a| ArgumentFactory.build(a) }
end
```

---

### F10 🟡 Medium Priority — `MethodCall#initialize` branches on a polymorphic subtype concern

**Reviewer(s):** Code Best Practices
**File:** `lib/fastererer/method_call.rb` (lines 9–20)
**Issue:** `MethodCall` wraps two structurally different node types
(`Prism::CallNode` and `Prism::LambdaNode`) and branches on which in the
constructor. The two arms share no initialization. This leaks across the class:
`block?`, `lambda_literal?`, and every `MethodCall` call site must be aware
that the lambda branch exists. `set_lambda_defaults` invents a fake `:lambda`
method name to paper over the polymorphism.

**Fix:**

```ruby
def self.build(node)
  node.is_a?(Prism::LambdaNode) ? LambdaCall.new(node) : new(node)
end
```

This also addresses F7's dead-code concern more completely.

---

### F11 🟡 Medium Priority — Manual `traverse_tree` in `MethodDefinitionScanner` re-implements Prism::Visitor

**Reviewer(s):** Ruby Idiom
**File:** `lib/fastererer/scanners/method_definition_scanner.rb` (lines 48–58)
**Issue:** The hand-rolled recursion allocates `node.compact_child_nodes` (a
new array) at every visited node and is inconsistent with `AnalyzerVisitor`.
More critically: it descends into *nested* `def` nodes, so a `block.call`
inside an inner method would trigger the outer method's offense even though
the `&block` parameter is not in scope there.

**Fix:** Replace with a `Prism::Visitor` subclass that short-circuits on
nested `def`, `class`, and `module` bodies.

---

### F12 🟢 Low Priority — Spec setup duplicated 11 times in new `describe` blocks

**Reviewer(s):** Code Best Practices, Test Coverage
**File:** `spec/lib/fastererer/method_call_spec.rb` (lines 473–572)
**Issue:** Each new `describe` block repeats:

```ruby
parsed = Fastererer::Parser.parse('...')
node = parsed.value.statements.body.first
mc = described_class.new(node)
```

This pattern appears 11 times. The rest of the spec file uses `let(:parsed)`,
`let(:first_statement)`, `let(:call_element)`, and `let(:method_call)`.

**Fix:** Wire the new blocks into the existing `let` infrastructure.

---

### F13 🟢 Low Priority — `Argument#type` returns `:unknown` as a silent fallback

**Reviewer(s):** Code Best Practices
**File:** `lib/fastererer/method_call.rb` (line 142)
**Issue:** Any node class not in `TYPE_BY_NODE_CLASS` — nil, local variables,
method calls, booleans — becomes `:unknown`. A scanner asking
`argument.type == :string` to detect a hardcoded string argument will get a
false negative when the argument is a variable. The `:unknown` fallback also
means new node types that should be mapped are silently ignored.

**Fix:** Consider raising or logging `:unknown` hits in development, or extend
the map with common cases (`LocalVariableReadNode`, `CallNode`, `NilNode`).

---

### F14 🟢 Low Priority — `RegularExpressionNode` and related literals missing from `PRIMITIVE_NODE_TYPES`

**Reviewer(s):** Ruby Idiom
**File:** `lib/fastererer/method_call.rb` (line 78)
**Issue:** The old code recognized `:lit` receivers as primitives, which
covered regexps, rationals, and imaginary numbers. The new list omits
`RegularExpressionNode`, `InterpolatedStringNode`, `RationalNode`, and
`ImaginaryNode`. If any future check does `receiver.is_a?(Primitive)`, regexp
receivers will be silently ignored.

**Fix:** Add the missing types, or add a comment documenting why they are
intentionally excluded.

---

### F15 🟢 Low Priority — `traverse_tree` parameter name `nodes` is misleading

**Reviewer(s):** Code Best Practices
**File:** `lib/fastererer/scanners/method_definition_scanner.rb` (lines 48–58)
**Issue:** The parameter is always an enumerable of `Prism::Node` objects, but
the name `nodes` reads like a single node to a new reader.

**Fix:** Rename to `node_list`, or (preferred) replace with `Prism::Visitor`
per F11.

---

### F16 🟢 Low Priority — Multi-line comment blocks violate the one-line comment convention

**Reviewer(s):** Code Best Practices
**Files:** `lib/fastererer/analyzer.rb` (lines 41–42), `lib/fastererer/parser.rb` (lines 6–7)
**Issue:** Both files contain two-line comment preambles. Project convention is
one-line comments.

**Fix:** Collapse each to a single line, or fix the underlying design concern
and delete the comment in `analyzer.rb`.

---

### F17 🟢 Low Priority — `output_parse_errors` message references timeouts that no longer occur

**Reviewer(s):** Security
**File:** `lib/fastererer/file_traverser.rb` (lines 103–105)
**Issue:** The user-facing message says "internal parser is not able to read
some characters or has timed out." No `Timeout.timeout` call exists in the
codebase after this migration.

**Fix:** Update the message to "Fastererer was unable to process some files."

---

### F18 🟢 Low Priority — `AnalyzerVisitor` specs do not assert that traversal continues into children

**Reviewer(s):** Test Coverage
**File:** `spec/lib/fastererer/analyzer_visitor_spec.rb` (lines 9–62)
**Issue:** Each `visit_*_node` method ends with `super`, which is essential for
descent into child nodes. The current specs only assert dispatch — they do not
verify that `super` propagates the visit. A bug removing `super` would still
pass all specs.

**Fix:** Add an integration spec that asserts a nested call is also visited
(e.g., `foo(bar(baz))` should fire `scan_method_calls` three times).

---

### F19 🟢 Low Priority — `BlockArgument` spec bypasses `Fastererer::Parser` wrapper

**Reviewer(s):** Test Coverage
**File:** `spec/lib/fastererer/method_call_spec.rb` (line 568)
**Issue:** `node = Prism.parse('foo(&block)').value.statements.body.first.block`
calls Prism directly, bypassing the `Fastererer::Parser` wrapper that every
other spec uses.

**Fix:** Change to `Fastererer::Parser.parse('foo(&block)').value.statements.body.first.block`.

---

### F20 🟢 Low Priority — `ConstantReadNode | ConstantPathNode` case duplicated across `MethodCall` and `RescueCall`

**Reviewer(s):** Code Best Practices
**Files:** `lib/fastererer/method_call.rb` (lines 86–87), `lib/fastererer/rescue_call.rb` (lines 17–20)
**Issue:** Both files independently handle `ConstantReadNode | ConstantPathNode`
as the "named constant" shape.

**Fix:** Low priority — only worth extracting to a shared predicate if a third
call site appears.

---

### F21 ℹ️ Observation — `Prism::Visitor` subclassing is the right architectural move

Replacing the hand-rolled `traverse_sexp_tree` / `descend_into_call` /
`scan_by_token` chain with `Prism::Visitor` is a clear win: fewer lines,
well-typed dispatch per node class, and no risk of "forgot to descend into
this branch" bugs.

---

### F22 ℹ️ Observation — `ArgumentFactory` / `ReceiverFactory` separation is good factoring

Introducing factory build methods to handle polymorphism — rather than
re-checking node type at every scanner — is the correct approach. Each scanner
now works with a typed domain object rather than a raw AST node.

---

### F23 ℹ️ Observation — `TYPE_BY_NODE_CLASS` frozen constant is the right call

Replacing a `case/when` chain with a frozen class-keyed hash adds new type
mappings as new rows, not edits to flow control.

---

### F24 ℹ️ Observation — `unwrap_parentheses` adds new functionality cleanly

The old code did not handle `(arr).map { }` correctly; the new helper does, with
matching specs.

---

### F25 ℹ️ Observation — Supply-chain posture improved

Dropping `ruby_parser >= 3.22.0` (third-party gem, single maintainer) in favour
of `prism >= 1.3.0` (canonical Ruby parser maintained by Ruby core, bundled with
Ruby >= 3.3) reduces transitive dependencies and aligns with the official
upstream.

---

### F26 ℹ️ Observation — No execution of parsed content

Verified that no part of the new visitor pipeline calls `eval`, `instance_eval`,
`class_eval`, or `module_eval` on AST nodes or extracted strings. The `send`
call in `method_call_scanner.rb` dispatches to internal `check_*` methods via a
hardcoded symbol map, not user-supplied content.

---

### F27 ℹ️ Observation — `Sexp` artifacts fully removed from specs

All `Sexp.new` artifacts from the old `ruby_parser` era are gone from the spec
suite. New fixtures are wired up with no orphans.

---

## Consolidated Summary

| Finding | Priority | Category | Description | File | Status |
|---------|----------|----------|-------------|------|--------|
| F1 | 🟠 High | Error Handling | `rescue StandardError` swallows all errors as parse errors | `file_traverser.rb:59` | — |
| F2 | 🟠 High | Bug | `set_block_argument_names` drops optional/keyword/splat block params | `method_call.rb:72` | — |
| F3 | 🟠 High | Error Handling | Multi-error parse results silently discard all but first error | `analyzer.rb:28–31` | — |
| F4 | 🟡 Medium | Dead Code | `BlockArgument` / `:block_pass` `ArgumentFactory` branch unreachable | `method_call.rb:113–158` | — |
| F5 | 🟡 Medium | Design | `Parser.parse` leaks `Prism::ParseResult` API to all callers | `parser.rb:10` | — |
| F6 | 🟡 Medium | Bug | `MethodDefinition#set_arguments` silently drops rest/kwargs/block params | `method_definition.rb:44` | — |
| F7 | 🟡 Medium | Dead Code | `visit_lambda_node` allocates objects but does nothing | `analyzer.rb:90` | — |
| F8 | 🟡 Medium | Design | `Analyzer` exposes 4 internal callbacks as public API | `analyzer.rb:41–61` | — |
| F9 | 🟡 Medium | Code Quality | `set_*` mutator pattern — eager, procedural, not reusable | `method_call.rb`, `method_definition.rb`, `rescue_call.rb` | — |
| F10 | 🟡 Medium | Design | `MethodCall#initialize` branches on a polymorphic subtype | `method_call.rb:9–20` | — |
| F11 | 🟡 Medium | Bug | Manual `traverse_tree` descends into nested `def` scopes incorrectly | `method_definition_scanner.rb:48–58` | — |
| F12 | 🟢 Low | Testing | Spec setup duplicated 11 times in new `describe` blocks | `method_call_spec.rb:473–572` | — |
| F13 | 🟢 Low | Code Quality | `Argument#type` returns `:unknown` silently for all unmapped types | `method_call.rb:142` | — |
| F14 | 🟢 Low | Code Quality | `RegularExpressionNode` and friends missing from `PRIMITIVE_NODE_TYPES` | `method_call.rb:78` | — |
| F15 | 🟢 Low | Naming | `traverse_tree` parameter name `nodes` is misleading | `method_definition_scanner.rb:48` | — |
| F16 | 🟢 Low | Style | Multi-line comment blocks violate one-line comment convention | `analyzer.rb:41–42`, `parser.rb:6–7` | — |
| F17 | 🟢 Low | Accuracy | `output_parse_errors` message mentions timeouts that no longer occur | `file_traverser.rb:103–105` | — |
| F18 | 🟢 Low | Testing | `AnalyzerVisitor` specs don't verify traversal continues via `super` | `analyzer_visitor_spec.rb:9–62` | — |
| F19 | 🟢 Low | Testing | `BlockArgument` spec bypasses `Fastererer::Parser` wrapper | `method_call_spec.rb:568` | — |
| F20 | 🟢 Low | DRY | `ConstantReadNode | ConstantPathNode` case duplicated across two files | `method_call.rb:86–87`, `rescue_call.rb:17–20` | — |
| F21 | ℹ️ Observation | Design | `Prism::Visitor` subclassing is the right architectural move | `analyzer.rb` | — |
| F22 | ℹ️ Observation | Design | `ArgumentFactory` / `ReceiverFactory` separation is good factoring | `method_call.rb` | — |
| F23 | ℹ️ Observation | Code Quality | `TYPE_BY_NODE_CLASS` frozen constant is the right call | `method_call.rb` | — |
| F24 | ℹ️ Observation | Code Quality | `unwrap_parentheses` adds new functionality cleanly | `method_call.rb` | — |
| F25 | ℹ️ Observation | Security | Supply-chain posture improved (ruby_parser → prism) | `fastererer.gemspec` | — |
| F26 | ℹ️ Observation | Security | No execution of parsed content | `scanners/` | — |
| F27 | ℹ️ Observation | Testing | `Sexp` artifacts fully removed from specs | `spec/` | — |

## Pre-Merge Checklist

- [ ] F1 — Narrow `rescue StandardError` to `Fastererer::ParseError, Errno::ENOENT`; update the timeout message
- [ ] F2 — Include all block param categories in `set_block_argument_names`; add specs pinning the behavior
- [ ] F3 — Surface all Prism errors in `ParseError`; add a spec for multi-error input
- [ ] F4 — Remove or properly wire `BlockArgument` / `:block_pass` `ArgumentFactory` branch
- [ ] F5 — Have `Parser.parse` return the AST root and raise on failure; extract `parse_first_statement` helper to spec
- [ ] F6 — Include rest/kwargs/block params in `MethodDefinition#set_arguments` (or rename the reader)
- [ ] F7 — Remove `visit_lambda_node` from `AnalyzerVisitor` and its spec
- [ ] F8 — Encapsulate `AnalyzerVisitor` via `private_constant` or merge scanning logic into the visitor
- [ ] F9 — Replace `set_*` mutators with memoized readers
- [ ] F10 — Extract `LambdaCall` subclass or `MethodCall.build` factory
- [ ] F11 — Replace manual `traverse_tree` with a `Prism::Visitor` that skips nested `def` scopes
- [ ] F12 — Wire new spec blocks into the existing `let` infrastructure
- [ ] F13 — Raise or log on `:unknown` type hits during development
- [ ] F14 — Add `RegularExpressionNode`, `RationalNode`, `ImaginaryNode` to `PRIMITIVE_NODE_TYPES`
- [ ] F15 — Rename `nodes` parameter to `node_list` (or fix via F11)
- [ ] F16 — Collapse multi-line comment blocks to single lines
- [ ] F17 — Remove "or has timed out" from `output_parse_errors` message
- [ ] F18 — Add an integration spec asserting `super` propagates traversal to nested nodes
- [ ] F19 — Use `Fastererer::Parser.parse` in the `BlockArgument` spec
- [ ] F20 — Note as low priority; extract predicate if a third call site appears

## Positive Notes

- The `Prism::Visitor` dispatch is a meaningful improvement over the old
  hand-rolled traversal — type-safe, exhaustive by construction, and impossible
  to accidentally miss a branch.
- `ArgumentFactory` / `ReceiverFactory` factories cleanly separate the
  polymorphism concern from scanning logic.
- `TYPE_BY_NODE_CLASS` as a frozen hash is idiomatic Ruby — extending the type
  system is additive and requires no changes to flow control.
- `unwrap_parentheses` correctly handles `(arr).map { }`, a case the old code
  missed, with matching specs.
- Dropping `ruby_parser` for Prism reduces transitive dependencies and aligns
  with the canonical upstream Ruby parser.
- No `eval` or code execution on parsed content — the `send` dispatch in
  `method_call_scanner.rb` is over a hardcoded internal symbol map.
- All `Sexp` artifacts from `ruby_parser` are cleanly removed with no orphaned
  fixtures.
