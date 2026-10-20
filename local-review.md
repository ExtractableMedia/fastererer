# Local Review — `github-annotations-format` (PR #93)

## Review History

- **Initial review:** 2026-09-04 (commits `d57165f`, `041d7fd`)
- **Reconciled:** 2026-09-04 — 11 findings fixed in `e56e3f5`; F21 and F3 deferred to
  issues #94 and #95; F19, F27, F28 skipped as reviewed.

Reviewers: code-best-practices, ruby-expert, security-reviewer, test-suite-architect.
Baseline at time of review: `bin/rspec` 341 examples / 0 failures, 100% line and branch;
`bin/rubocop` clean; CI green on Ruby 3.3, 3.4 and 4.0.

---

## Code Best Practices

### F1 ~~🟡 Medium Priority - The documented workflow example fails the build, and the reviewdog example beside it does not~~ ✅ Fixed

**Status:** Fixed in `e56e3f5`.
**File:** `README.md` (CI integration, "Inline annotations on GitHub Actions")
**Recommendation:** Implement — one sentence, and the alternative is users discovering the
asymmetry on a red main branch. Corroborated independently by ruby-expert.

`exe/fastererer` exits `1` on offenses, so this step goes red:

```yaml
- name: Run fastererer
  run: bundle exec fastererer -f github
```

The reviewdog example two sections above is a *pipeline*, and GitHub's default shell is `bash -e`,
not `-o pipefail`, so that step's status is reviewdog's, not fastererer's. Two adjacent
copy-pasteable examples with opposite failure behavior, and nothing says so. The exit-code table
explains the mechanism but never connects it to these snippets.

```markdown
fastererer exits `1` when it finds anything, so this step fails the job. The annotations render
either way — add `continue-on-error: true` if you want them as advisory notes only. (The reviewdog
pipeline above exits with reviewdog's status, not fastererer's.)
```

### F2 ~~🟡 Medium Priority - "nothing is filtered to the pull request diff" oversells where annotations land~~ ✅ Fixed

**Status:** Fixed in `e56e3f5`.
**File:** `README.md` ("Inline annotations on GitHub Actions")
**Recommendation:** Implement — accuracy gap in a doc that gets the same point right two sections
earlier; a clause fixes it.

A `::warning` for a file the PR did not touch is *reported*, but GitHub will not render it inline
in Files Changed — it lands in the check run's annotation list. The reviewdog section already
documents this nuance carefully ("Findings outside the diff cannot be posted as inline review
comments"), so the new section is held to a standard the file sets for itself.

```markdown
Every finding is emitted; nothing is filtered to the pull request diff. As with reviewdog,
findings on lines the pull request does not touch appear in the check run's annotation list
rather than inline in Files Changed.
```

### F3 ~~🟡 Medium Priority - `github` is the only format that drops `finding.url`~~ ⏸️

**Status:** Deferred to issue #95 — https://github.com/ExtractableMedia/fastererer/issues/95
Changes the wire format, so it wants its own decision.
**File:** `lib/fastererer/formatters/github_formatter.rb:21-23`
**Recommendation:** Defer — a product call about annotation noise versus discoverability, not a
defect. The format is brand new, so there is no compatibility cost to changing it in a follow-up.

`text` renders the URL, `json` emits `url`, `rdjsonl` emits `code.url`. The annotation gives the
reviewer `rule_key: description` and no route to the fast-ruby rationale — and the annotation is
the *only* thing that reviewer sees. Workflow commands have a home for the display name too:

```ruby
def annotation(finding)
  "::warning file=#{property(finding.path)},line=#{finding.line}," \
    "title=#{property(finding.rule_name)}::#{message(finding)}"
end
```

*Severity/recommendation divergence:* the information loss is real, but the fix wants its own
decision and would churn the README, CHANGELOG and three specs.

### F4 ~~🟢 Low Priority - `property` has a load-bearing gsub order that nothing states~~ ✅ Fixed

**Status:** Fixed in `e56e3f5` — single-pass `PROPERTY_ESCAPES` hash. Folds in F13 and F20 too:
`percent_encode` no longer exists.
**File:** `lib/fastererer/formatters/github_formatter.rb:26-28`
**Recommendation:** Conflicting — code-best-practices says **Implement** (the file is new, so
there is no churn to weigh); ruby-expert says **Skip** (the chained form makes the encode ordering
visible on the page, which is the thing that actually matters). See F13.

```ruby
def property(value)
  percent_encode(sanitize(value)).gsub(':', '%3A').gsub(',', '%2C')
end
```

`percent_encode` must run first — swap the order and the `%` in a freshly produced `%3A` becomes
`%253A`. The comment explains why `:` and `,` are escaped but not the ordering constraint, which is
the subtler of the two. A single-pass substitution removes the constraint rather than documenting
it:

```ruby
PROPERTY_ESCAPES = { '%' => '%25', ':' => '%3A', ',' => '%2C' }.freeze
private_constant :PROPERTY_ESCAPES

def property(value)
  sanitize(value).gsub(/[%:,]/, PROPERTY_ESCAPES)
end
```

Not a latent bug: the `'a,b:c%d.rb'` example does guard the ordering — a reorder yields `a%252C…`
and the spec goes red. The cost is that a reader must reason about gsub order.

### F5 ~~🟢 Low Priority - `FORMAT_HELP` is public, unlike every other incidental constant~~ ✅ Fixed

**Status:** Fixed in `e56e3f5`.
**File:** `lib/fastererer/cli.rb:13`
**Recommendation:** Implement — one line, matches a convention the repo already applies twice.

`Base::UNSAFE_CHARS` and `RdjsonlFormatter::SEVERITY` are both `private_constant`.
`OFFENSES_FOUND_STATUS` / `USAGE_ERROR_STATUS` are public because they are arguably the CLI's
contract; a help string is not.

```ruby
FORMAT_HELP = 'Output format: text (default), json, rdjsonl, github'
private_constant :FORMAT_HELP
```

### F6 ~~🟢 Low Priority - `--help` hardcodes a format list that `Formatters` already derives~~ ✅ Fixed

**Status:** Fixed in `e56e3f5`.
**File:** `lib/fastererer/cli.rb:13` vs `lib/fastererer/formatters.rb:12-23`
**Recommendation:** Implement — not speculative DRY: two lists that must agree, and the codebase
already solved the identical problem in `fetch`. Flagged independently by all three of
code-best-practices, ruby-expert and test-suite-architect.

`Formatters.fetch` builds "Valid formats: text, json, rdjsonl, github." from `FORMATS.keys`, so the
error path is self-maintaining while `--help` is not. Nothing references `FORMAT_HELP` in any spec,
so a fifth format can ship undiscoverable from `--help` with a green build.

Either derive it:

```ruby
FORMAT_HELP = "Output format: #{Formatters::FORMATS.keys.join(', ')} (text is the default)"
```

or keep the hand-written phrasing and pin it (`spec/lib/fastererer/cli_spec.rb`):

```ruby
it 'names every registered format in the --format help' do
  expect { described_class.parse_options(['--help']) }
    .to output(a_string_including(*Fastererer::Formatters::FORMATS.keys)).to_stdout
    .and raise_error(SystemExit)
end
```

### F7 ~~🟢 Low Priority - README reference-link definitions are no longer alphabetized~~ ✅ Fixed

**Status:** Fixed in `e56e3f5`.
**File:** `README.md` (link definition block at the foot of the file)
**Recommendation:** Implement — moving two lines; sorted blocks stay sorted only if maintained.
Corroborated by ruby-expert.

The block was sorted (`damir-svrtan`, `discussions`, `fast-ruby`, `fasterer`, `issues`, `prism`,
`rdf`, `roadmap-project`, `sferik-talk`). `workflow-commands` and `annotation-limits` were appended
after `rdf`. `annotation-limits` belongs first, `workflow-commands` last. The CHANGELOG additions
*are* correctly sorted, so this reads as an oversight rather than a convention change.

### F8 ~~🟢 Low Priority - `let(:lines)` under-names what it holds~~ ✅ Fixed

**Status:** Fixed in `e56e3f5`.
**File:** `spec/lib/fastererer/formatters/github_formatter_spec.rb:13`
**Recommendation:** Implement — one `let` rename plus four call sites; resolves an inconsistency
internal to the new file.

`spec/CLAUDE.md` asks for names written out in full. The file already calls the expectation
`expected_annotations`, so `expect(lines).to eq(expected_annotations)` compares two things that
read as different kinds. The sibling `rdjsonl` spec uses `lines` legitimately — there the values
are raw JSON lines awaiting a `JSON.parse`; here they are the finished artifact.

---

## Ruby Expert

### F9 ~~🟡 Medium Priority - No test pins that `,` and `:` stay **raw** in the message~~ ✅ Fixed

**Status:** Fixed in `e56e3f5`.
**File:** `spec/lib/fastererer/formatters/github_formatter_spec.rb:39-57`
**Recommendation:** Implement — six lines, and it guards the one asymmetry a maintainer is most
likely to "fix" incorrectly.

The spec covers separators in the *path* and `%` in the *description*, but never asserts the
asymmetry: commas and colons are property separators **only**, and must survive untouched in the
message. Not academic — a shipped description already contains a comma (`config/locales/en.yml`,
`rescue_vs_respond_to`: "Don't rescue NoMethodError, rather check with respond_to?"). A future
"just encode everywhere, it's safer" refactor would mangle a real rule's output with a green suite.

```ruby
context 'with a comma and colon in the description' do
  let(:findings) { [finding(path: 'a.rb', line: 1, description: 'Rescue NoMethodError, use: x')] }

  before { formatter.render(report(findings: findings, inspected: 1)) }

  it 'leaves them raw, since only property values treat them as separators' do
    expect(lines.first).to end_with('::slow_thing: Rescue NoMethodError, use: x')
  end
end
```

### F10 ~~🟡 Medium Priority - The annotation-limit claim is inaccurate and under-cited~~ ✅ Fixed

**Status:** Fixed in `e56e3f5`.
**File:** `README.md` ("Inline annotations on GitHub Actions")
**Recommendation:** Implement — this is the sentence steering readers between the two
integrations, so it should be right.

GitHub documents both numbers officially (`docs.github.com/en/rest/checks/runs`): *"GitHub Actions
are limited to 10 warning annotations and 10 error annotations per step"* and *"The Checks API
limits the number of annotations to a maximum of 50 per API request."* The 50 is a **per-request**
cap on the Checks API, not a per-job ceiling — and it is worked around by paginating, which
reviewdog does. Citing a community discussion for a documented limit is also weaker than needed,
and discussions rot.

```markdown
GitHub caps Actions annotations at [10 warnings per step][annotation-limits], and silently drops
the rest with no indication in the UI.
```

```markdown
[annotation-limits]: https://docs.github.com/en/rest/checks/runs
```

### F11 ~~🟢 Low Priority - "which has no such cap" overstates the reviewdog path~~ ✅ Fixed

**Status:** Fixed in `e56e3f5`.
**File:** `README.md` ("Inline annotations on GitHub Actions", final paragraph)
**Recommendation:** Implement alongside F10 — same sentence.

The README's own reviewdog section says out-of-diff findings fall back to check annotations, which
go through the Checks API. The advantage is real (reviewdog paginates and posts threaded review
comments for in-diff findings), but "no such cap" is too absolute. "which paginates past that limit
and posts threaded, resolvable review comments" keeps the recommendation intact.

### F12 💡 Observation (optional action) - `finding.line` is the only interpolation that bypasses escaping

**File:** `lib/fastererer/formatters/github_formatter.rb:18`

`line=#{finding.line}` is raw. With a non-integer it would inject:
`line: '1::error::x'` → `::warning file=a.rb,line=1::error::x::k: d`. Unreachable today —
`Finding#line` comes from `Offense#line_number`, i.e. `element.location.start_line`, always an
`Integer`. `Finding` is a `Data` with no coercion, so this is a latent seam, not a bug. Adding
`.to_i` would be defensive code for a state the parser cannot produce, which this repo's
conventions leave out. Noted so the seam is on record if `Finding` ever widens.

### F13 💡 Observation (optional action) - Five `gsub` passes per finding

**File:** `lib/fastererer/formatters/github_formatter.rb:22-33`

Each finding allocates through `sanitize` (`to_s`, `scrub`, `gsub`) plus up to three more `gsub`
passes, each allocating even on no match. A single-pass hash substitution (see F4) would avoid it.
Optional: this is the output path for a format whose entire audience is capped at 10 rendered
annotations per step, there is no benchmark harness in the repo, and the chained form makes the
encode ordering visible. Trading that legibility for an unmeasured win is the wrong call.

### F14 ℹ️ Observation - The encode/decode ordering is correct, and correct for a reason

**File:** `lib/fastererer/formatters/github_formatter.rb:26-33`

Verified against `actions/runner` source, not the docs. The runner decodes with `%25` **last**:
`UnescapeProperty` is `%0D → %0A → %3A → %2C → %25`; `UnescapeData` is `%0D → %0A → %25`. The
formatter encodes `%` **first**, the exact inverse — which is what makes it double-encoding-safe:

```text
path  a%3Ab.rb    → emitted a%253Ab.rb  → decoded a%3Ab.rb   ✅
desc  "%0A here"  → emitted "%250A here" → decoded "%0A here" ✅
```

Reorder the two gsubs in `property` and `a:b.rb` would decode to the literal `%3A`.

### F15 ℹ️ Observation - `Base#sanitize` genuinely substitutes for `%0D`/`%0A` encoding

**File:** `lib/fastererer/formatters/base.rb:7`

`UNSAFE_CHARS = /[\x00-\x08\x0A-\x1F\x7F]/` covers CR and LF, converting them to literal `\x0D` /
`\x0A` text. A *rendering* difference from GitHub's `%0A` (which would produce a real line break in
the annotation body), not a correctness one — and every rule description in `en.yml` is
single-line. Consistent with the sibling formatters. Recorded so a future reader does not "fix" it
toward `%0A`.

### F16 ℹ️ Observation - Workflow-command forgery on **stdout** is not exploitable

**File:** `lib/fastererer/formatters/github_formatter.rb:17-34`

Confirmed by both ruby-expert and security-reviewer against runner source, and reproduced locally
over hostile paths. `ActionCommand.TryParseV2` requires the line to start with `::` and splits the
command block from the data at the **first** subsequent `::`, so the message is the final segment
and an embedded `::error::` is inert text. Escaping to a new command requires a line break, which
`sanitize` removes. The `#{rule_key}: ` prefix adds a second layer for free. Sample output:

```text
::warning file=%3A%3Astop-commands%3A%3Atok,line=1::k: Slow
::warning file=a\x0D\x0A%3A%3Aerror%3A%3Apwned,line=1::k: Slow
::warning file=a%2Cline=999%2Ccol=1.rb,line=1::k: Slow
```

### F17 💡 Observation (optional action) - `UNSAFE_CHARS` does not cover U+0085 / U+2028 / U+2029

**File:** `lib/fastererer/formatters/base.rb:7`

NEL and the Unicode line/paragraph separators pass through raw, and do not need escaping: the
runner reads process stdout with .NET line semantics (CR, LF, CRLF only — `` and ` ` are
explicitly not terminators for `StreamReader.ReadLine`). Pre-existing `Base` behavior shared by all
four formats; widening the regex here would change all of them for no gain.

### F18 ℹ️ Observation - A tab degrades an annotation, it does not break one

**File:** `lib/fastererer/formatters/base.rb:6-7`

A tab survives `sanitize` by design and lands raw inside `file=`. `TryParseV2` trims only leading
whitespace on the whole line and tab is not a property separator, so the command still parses; the
path simply fails to match a repository file and the annotation degrades from inline to job-level.
That is the correct failure mode.

### F19 ~~🟢 Low Priority - `::warning` is inlined where the sibling uses a private constant~~ 🚫

**Status:** Skipped — pure churn, as the reviewer recommended.
**File:** `lib/fastererer/formatters/github_formatter.rb:18` vs `rdjsonl_formatter.rb:11-12`
**Recommendation:** Skip — pure churn. `::warning` inside the format string is arguably clearer
than a constant, since the literal *is* the wire format.

### F20 🟢 Low Priority - `percent_encode` encodes exactly one character

**File:** `lib/fastererer/formatters/github_formatter.rb:31-33`
**Recommendation:** Skip — a rename with no behavior change. `escape_percent` would say what it
does, but the one-line comment above already carries the why.

---

## Security

### F21 ~~🟠 High Priority - `::stop-commands` injection via a crafted file name on **stderr**~~ ⏸️

**Status:** Deferred to issue #94 — https://github.com/ExtractableMedia/fastererer/issues/94
The exposure is in `Base` and affects `text`, `json` and `rdjsonl` too. A `github`-only fix would
leave the `text` stdout vector open while appearing complete — see the issue for that variant,
which needs no parse error at all.
**File:** `lib/fastererer/formatters/base.rb:20-25`, reached from
`lib/fastererer/formatters/github_formatter.rb:10`; payload built at
`lib/fastererer/file_traverser.rb:114`
**Recommendation:** Implement — the exposure predates this branch, but this is the change that
makes "our output is parsed by the Actions runner" a designed interface and documents running it
that way. The fix is ~6 lines and directly protects the feature being shipped.

**Independently reproduced during this review** (not taken on the reviewer's word). `ErrorData#to_s`
is `"#{file_path} - #{error_class} - #{error_message}"` — the line **begins** with the
attacker-controlled path. `sanitize` escapes control characters but leaves `:` and `#` alone, and
unlike `GithubFormatter#property` there is no percent-encoding on this path. Actual stderr from
`fastererer -f github` over a directory containing two unparsable files:

```text
::stop-commands::tok.rb - Fastererer::ParseError - unexpected end-of-input; expected a `)` …
a##[stop-commands]t.rb - Fastererer::ParseError - unexpected end-of-input; expected a `)` …
```

Both halves of the claim were verified against `actions/runner` source:

- `ScriptHandler.cs`: `StepHost.OutputDataReceived += stdoutManager.OnDataReceived;` **and**
  `StepHost.ErrorDataReceived += stderrManager.OnDataReceived;` — stderr *is* scanned, through the
  same `ActionCommandManager`.
- `ActionCommandManager.TryProcessCommand` runs `TryParseV2(...) || TryParse(...)`; the V1
  (`##[cmd]`) parser is still live.
- `ValidateStopToken` rejects only already-registered commands, empty strings, and
  `pause-logging`.

**Risk:** an attacker opening a pull request from a fork adds one file named
`::stop-commands::tok.rb` (or `lib/a##[stop-commands]t.rb`, which needs no leading `::` and uses
only characters legal in filenames on every platform) containing invalid Ruby. Command processing
flips off, and because the token contains spaces it can never be re-matched, so it stays off for
the rest of the step. Every `::warning` fastererer emits is dropped, along with any other tool's
annotations and masking in the same step. `render` writes diagnostics before findings, and stderr
is unbuffered while stdout to a pipe is block-buffered, so the suppression reliably precedes the
annotations.

**Mitigating:** `CLI.exit_with_status_for` still exits `1` on offenses regardless of format, so the
step still fails. The bypass hides the findings, not the failure. That is why this is High and not
Critical.

**Remediation** — route diagnostics through an overridable hook so only the format consumed by the
runner pays for it. In `base.rb`:

```ruby
def output_diagnostics(report)
  missing_path = report.missing_path

  err.puts(diagnostic_line(missing_path)) if missing_path
  report.unparsable_files.each { |file| err.puts(diagnostic_line(file.to_s)) }
end

def diagnostic_line(text)
  sanitize(text)
end
```

In `github_formatter.rb`:

```ruby
# The runner scans stderr for commands too, accepting "::" at the start of a line and "##["
# anywhere, so a crafted file name could forge one
def diagnostic_line(text)
  super.sub(/\A\s*::/) { |opener| opener.sub('::', '%3A%3A') }.gsub('##[', '%23%23[')
end
```

This leaves `Fastererer::ParseError` readable mid-line and rewrites only the two sequences the
runner treats as openers.

### F22 ~~🟢 Low Priority - README's `github` section omits the absolute-path disclosure warning~~ ✅ Fixed

**Status:** Fixed in `e56e3f5`.
**File:** `README.md` ("Inline annotations on GitHub Actions") vs the reviewdog section above it
**Recommendation:** Implement — one sentence, and the asymmetry between two adjacent sections
documenting the same hazard reads as intentional to a future editor.

The reviewdog section spells out the consequence: an absolute directory "emits absolute paths that
will not match — and puts the runner's directory layout in a public comment." The new section says
only that annotations "are anchored by repository-relative path," leaning on "As with reviewdog" to
carry the rest. Annotations render in the Checks UI of a public repository, and on a self-hosted
runner the path can include a username or internal directory structure rather than the well-known
`/home/runner/work/...`.

```markdown
… since annotations are anchored by repository-relative path — an absolute path both fails to
anchor and puts the runner's directory layout in a publicly visible check run.
```

### F23 ℹ️ Observation - The 10-warning cap is a weak finding-suppression primitive

**File:** `README.md` ("Inline annotations on GitHub Actions")

An attacker can pad a PR with trivial findings to push a real one out of the rendered set. The
README already documents the cap honestly, and `CLI.exit_with_status_for` still exits `1` whenever
any offense exists, so the step fails regardless of what renders. The gate is not bypassable, only
the display.

### F24 ℹ️ Observation - Clean on the remaining threat-model categories

- **Untrusted input:** the new formatter performs no parsing, loading or evaluation. All
  `add_offense` call sites still pass literal symbols; the `RuleCatalog.validate!` chokepoint is
  untouched.
- **Denial of service:** the new `gsub` calls take **String** arguments, not Regexp — no regex
  engine, no backtracking, no ReDoS. Four linear passes per finding.
- **Filesystem:** the new formatter opens, globs and resolves nothing; `file=` is an opaque string
  the runner does not read.
- **Command injection:** no `system`, backticks, `exec`, `Open3` or `spawn` outside the specs.
- **Supply chain:** neither the gemspec nor `Gemfile.lock` is touched — correct for a feature
  branch.

---

## Test Coverage

### F25 ~~🟠 High Priority - A control character in the **path** is never asserted~~ ✅ Fixed

**Status:** Fixed in `e56e3f5` — mutation re-run confirms the new example is the one that kills it.
**File:** `spec/lib/fastererer/formatters/github_formatter_spec.rb` (path contexts)
**Recommendation:** Implement — a four-line context mirroring the existing description example,
and it is the only unpinned line of the new class.

`github_formatter.rb:26` calls `sanitize` inside `property`, but every path example uses printable
characters only. The control-character example exercises the *description*, which reaches
`sanitize` through `message` — a different call site.

**Proof:** dropping `sanitize` from `property` alone — `percent_encode(sanitize(value))` →
`percent_encode(value)` — **passes the entire suite: 341 examples, 0 failures, 100% line, 100%
branch.** Line coverage counts that `sanitize` *ran*, not that anything depended on its result.

This is the one input in the format that is genuinely attacker-influenced: paths come from file
names on disk, descriptions come from `config/locales/en.yml`. Without `sanitize`, a file named
with an embedded newline splits one `::warning` line in two and the runner silently drops it.
(The injected `::` on the continuation line still gets percent-encoded by the trailing gsubs, so
this corrupts output rather than forging a command — hence High, not Critical.)

```ruby
context 'with a control character in the path' do
  let(:findings) { [finding(path: "ev\nil.rb", line: 3, description: 'Slow')] }

  before { formatter.render(report(findings: findings, inspected: 1)) }

  it 'escapes it so a crafted file name cannot open a second command' do
    expect(lines).to eq(['::warning file=ev\\x0Ail.rb,line=3::slow_thing: Slow'])
  end
end
```

Verified in a scratch copy: passes on clean code, fails under the dropped-`sanitize` mutation,
RuboCop-clean.

### F26 ~~🟡 Medium Priority - The exe spec pins a locale string unrelated to this format~~ ✅ Fixed

**Status:** Fixed in `e56e3f5`.
**File:** `spec/exe/fastererer_spec.rb:106-112`
**Recommendation:** Implement — one-line change, removes a verbatim coupling to `en.yml` while
still pinning the command syntax, path, line and rule key.

The example asserts full stdout with `eq`, embedding `Array#shuffle.first is slower than
Array#sample` — copy that lives in `config/locales/en.yml`. Its sibling one example above
deliberately asserts only structure and touches no description text. Rewording that YAML entry
would break a black-box CLI test for an unrelated reason.

```ruby
it 'emits a workflow command naming the configuration key with -f github' do
  stdout, = Open3.capture3(fasterer_bin, '-f', 'github')

  expect(stdout).to start_with('::warning file=user.rb,line=1::shuffle_first_vs_sample: ')
end
```

The exact-line-and-trailing-newline property the `eq` carried is already owned by the unit spec's
`expect(lines).to eq(expected_annotations)`.

### F27 ~~🟢 Low Priority - Emission order is unpinned~~ 🚫

**Status:** Skipped — the behavior is unobservable at runtime.
**File:** `lib/fastererer/formatters/github_formatter.rb:12`
**Recommendation:** Skip — the behavior it would guard is unobservable.

`render` iterates `report.findings` unsorted, unlike `JsonFormatter#offenses` which sorts by
`[path, line]`. Adding a sort passes both specs, so the mutation genuinely survives. But the real
binary already emits in path-then-line order (`FileTraverser` walks files in sorted glob order, the
analyzer walks the AST in source order), so the divergence is invisible at runtime — including
under the 10-annotation cap, where truncation order would otherwise be user-visible. A test
asserting "does not sort" would pin incidental behavior.

*Severity/recommendation divergence:* the mutation survives, but what it guards cannot be observed.

### F28 ~~🟢 Low Priority - `'excludes the statistics line'` is subsumed by the `eq` assertion~~ 🚫

**Status:** Skipped — names an intent cheaply.
**File:** `spec/lib/fastererer/formatters/github_formatter_spec.rb:34-36`
**Recommendation:** Skip — deleting it is polish in the other direction; it names an intent cheaply
and keeps the three formatter specs readable side by side.

An exact array comparison four lines above cannot pass with a statistics line present. In the
rdjsonl spec the same example is *not* redundant, since that spec only checks counts and parsed
locations.

### F29 ℹ️ Observation - Cases considered and deliberately not tested

Each was verified as already covered or incidental: a **tab** in a path or message (harmless;
`Base`'s declared exemption); a path **already containing a percent-encoded sequence** (`a%2Cb.rb`
→ `a%252Cb.rb` → decodes back correctly; the `%` leg is already exercised); a literal **`::` in a
message** (the asymmetry is already pinned — changing `message` to use `property` fails 4 examples
across the unit and exe specs); **`--format github` in `cli_spec.rb`** (that spec's `json` context
exists to prove the injected `out:` stream is honored, which is format-agnostic wiring already
proven; `rdjsonl` is likewise covered only at the exe level, and this commit followed that
precedent).

### F30 ℹ️ Observation - Spec conventions are met

`spec/lib/fastererer/formatters/github_formatter_spec.rb` conforms to `spec/CLAUDE.md`: three
levels of nesting, one `context` per precondition with an `it` naming only the resulting behavior,
single-line `let`/`before`, names written out in full, no stubbing of the subject, and the same
`FormatterHelpers` + `StringIO` shape as its two siblings. The `lines(chomp: true)` divergence from
the rdjsonl spec is justified — this format is compared as plain strings, not parsed. The
`formatters_spec.rb` changes are complete: the new `fetch('github')` example matches its three
siblings, and the error-message update is required by `FORMATS.keys.join`, so it is a real
assertion rather than churn.

---

## Consolidated Summary

| Finding | Priority | Category | Description | File | Recommendation | Status |
|---------|----------|----------|-------------|------|----------------|--------|
| F21 | 🟠 High | Security | `::stop-commands` injection via file name on stderr | `formatters/base.rb` | Implement | ⏸️ #94 |
| F25 | 🟠 High | Testing | Control character in path never asserted (mutation survives) | `github_formatter_spec.rb` | Implement | ✅ |
| F1 | 🟡 Medium | Documentation | Workflow example fails the build, undocumented | `README.md` | Implement | ✅ |
| F2 | 🟡 Medium | Documentation | Oversells where annotations render | `README.md` | Implement | ✅ |
| F3 | 🟡 Medium | Code Quality | Only format that drops `finding.url` | `github_formatter.rb` | Defer | ⏸️ #95 |
| F9 | 🟡 Medium | Testing | `,`/`:` staying raw in the message is unpinned | `github_formatter_spec.rb` | Implement | ✅ |
| F10 | 🟡 Medium | Documentation | Annotation-limit claim inaccurate, weak citation | `README.md` | Implement | ✅ |
| F26 | 🟡 Medium | Testing | Exe spec hardcodes an `en.yml` description | `fastererer_spec.rb` | Implement | ✅ |
| F4 | 🟢 Low | Code Quality | Load-bearing gsub order is unstated | `github_formatter.rb` | Implement | ✅ |
| F5 | 🟢 Low | Code Quality | `FORMAT_HELP` should be `private_constant` | `cli.rb` | Implement | ✅ |
| F6 | 🟢 Low | Code Quality | `--help` list can drift from `FORMATS` | `cli.rb` | Implement | ✅ |
| F7 | 🟢 Low | Documentation | Reference-link block no longer alphabetized | `README.md` | Implement | ✅ |
| F8 | 🟢 Low | Testing | `let(:lines)` under-named | `github_formatter_spec.rb` | Implement | ✅ |
| F11 | 🟢 Low | Documentation | "no such cap" overstates reviewdog | `README.md` | Implement | ✅ |
| F22 | 🟢 Low | Security | Absolute-path disclosure warning omitted | `README.md` | Implement | ✅ |
| F19 | 🟢 Low | Code Quality | `::warning` inlined vs a constant | `github_formatter.rb` | Skip | 🚫 |
| F20 | 🟢 Low | Code Quality | `percent_encode` name overpromises | `github_formatter.rb` | Resolved by F4 | ✅ |
| F27 | 🟢 Low | Testing | Emission order unpinned | `github_formatter.rb` | Skip | 🚫 |
| F28 | 🟢 Low | Testing | Redundant statistics-line example | `github_formatter_spec.rb` | Skip | 🚫 |
| F12 | 💡 Observation | Code Quality | `finding.line` bypasses escaping (unreachable) | `github_formatter.rb` | — | — |
| F13 | 💡 Observation | Performance | Five `gsub` passes per finding | `github_formatter.rb` | — | ✅ |
| F17 | 💡 Observation | Security | U+0085 / U+2028 / U+2029 unescaped (harmless) | `base.rb` | — | — |
| F14 | ℹ️ Observation | Security | Encode/decode ordering verified correct | `github_formatter.rb` | — | — |
| F15 | ℹ️ Observation | Code Quality | `sanitize` substitutes for `%0D`/`%0A` | `base.rb` | — | — |
| F16 | ℹ️ Observation | Security | Stdout forgery not exploitable (verified) | `github_formatter.rb` | — | — |
| F18 | ℹ️ Observation | Security | A tab degrades, does not break | `base.rb` | — | — |
| F23 | ℹ️ Observation | Security | Annotation cap is a weak suppression primitive | `README.md` | — | — |
| F24 | ℹ️ Observation | Security | Clean on remaining threat-model categories | — | — | — |
| F29 | ℹ️ Observation | Testing | Cases considered and deliberately not tested | — | — | — |
| F30 | ℹ️ Observation | Testing | Spec conventions met | `github_formatter_spec.rb` | — | — |

---

## Pre-Merge Checklist

All applied in commit `e56e3f5` unless marked otherwise.

- [x] F25 - Add a control-character-in-path example (mutation re-run confirms it kills the mutant) ✅
- [x] F1 - Document that the workflow example fails the job on findings ✅
- [x] F2 - Correct the claim about where out-of-diff annotations render ✅
- [x] F9 - Pin that `,` and `:` stay raw in the message ✅
- [x] F10 - Correct and re-cite the annotation-limit numbers (README and CHANGELOG) ✅
- [x] F26 - Stop pinning an `en.yml` description string in the exe spec ✅
- [x] F4 - Single-pass `PROPERTY_ESCAPES` hash; resolves F13 and F20 as well ✅
- [x] F5 - Make `FORMAT_HELP` a `private_constant` ✅
- [x] F6 - Derive the `--help` format list from `FORMATS` ✅
- [x] F7 - Restore alphabetical order in the README link block ✅
- [x] F8 - Rename `let(:lines)` to `annotations` ✅
- [x] F11 - Soften "no such cap" for the reviewdog path ✅
- [x] F22 - Add the absolute-path disclosure warning to the `github` section ✅
- ⏸️ F21 - Workflow-command openers in output consumed by Actions (deferred to issue #94 — the
  exposure is in `Base` and affects `text`, `json` and `rdjsonl` too, so a `github`-only fix would
  leave the `text` stdout vector open while appearing complete)
- ⏸️ F3 - Emit `finding.url` / `title=` (deferred to issue #95 — changes the wire format)
- 🚫 F19 - `::warning` constant (skipped — pure churn)
- 🚫 F27 - Pin emission order (skipped — unobservable)
- 🚫 F28 - Delete the statistics-line example (skipped — cheap intent)

---

## Positive Feedback

- **F14/F16** — The escaping, the part worth being nervous about, is correct *and correct for the
  right reason*: `%`-first encoding mirroring the runner's `%25`-last decoding. Two reviewers
  independently attempted forgery against runner source and neither could construct one on stdout.
- **F30** — The new spec conforms to `spec/CLAUDE.md` without prompting, and the exe-level example
  asserting stdout byte-for-byte is stronger than its two siblings — the right call for a format
  whose entire contract is its literal text.
- `GithubFormatter` is 36 lines with no method longer than two, and earns that by *reusing* `Base`
  rather than reimplementing: `output_diagnostics` gives it the same stderr routing as `json` and
  `rdjsonl` for free. Registration is a one-line hash entry, and the unknown-format error message
  updated itself from `FORMATS.keys`.
- Documentation is complete across README, CHANGELOG and `--help`, with no stale format list
  anywhere else in the repo.
- `GithubFormatter` vs GitHub's own capitalization was considered by two reviewers and is the right
  call — it matches the lowercase `github` format key and avoids `git_hub_formatter.rb`, while the
  prose in README and CHANGELOG correctly writes "GitHub".
