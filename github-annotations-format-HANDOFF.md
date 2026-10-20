# Handoff: `github` output format for GitHub Actions annotations

**Status:** Ready for review — draft PR open, all in-scope review findings applied
**Created:** 2026-09-04
**Updated:** 2026-09-04
**Branch:** `github-annotations-format` (base: `main`)
**Pull request:** https://github.com/ExtractableMedia/fastererer/pull/93 (draft)
**Issues:** #56 (https://github.com/ExtractableMedia/fastererer/issues/56) — linked as a closing
reference on PR #93. Follow-ups opened from the review: #94
(https://github.com/ExtractableMedia/fastererer/issues/94) and #95
(https://github.com/ExtractableMedia/fastererer/issues/95)
**Captured by:** Opus 5 (`claude-opus-5[1m]`)

## Start Here

This branch implements issue #56: a `github` value for the `-f`/`--format` flag that emits GitHub
Actions workflow commands, which the Actions runner renders as inline pull request annotations with
no external tooling. The feature is **complete, committed, pushed, and green on CI**. A
four-reviewer local review produced 30 findings; the 11 in-scope actionable ones were applied in
commit `e56e3f5`, and the two that were out of scope became issues #94 and #95. **The branch is
finished** — the remaining action is to take PR #93 out of draft once the user is satisfied.

Re-orient before trusting anything below:

```bash
git status --short --branch
git --no-pager log --oneline -5
```

The state recorded here was accurate at capture time on 2026-09-04. Re-verify before relying on it.

## Objective

The user's request, verbatim:

> create a branch to implement https://github.com/ExtractableMedia/fastererer/issues/56 and then
> implement it. open a draft PR. then run /local-review and then run /handoff

Issue #56 asks for a `github` format emitting one
`::warning file=<path>,line=<line>::<rule>: <message>` line per offense, as a zero-dependency
alternative to the reviewdog integration (#38). Its stated scope:

- New `github` formatter, one workflow-command line per offense to stdout, diagnostics to stderr
  (consistent with the machine formats from #40)
- Reports all findings, no diff filtering
- Unit tests plus a README CI-integration subsection presenting it as the no-dependency alternative
  to reviewdog, including the annotation-cap trade-off

**Acceptance criteria:** all three bullets satisfied; `bin/rspec` green whole-suite at the 100% line
and branch floors; `bin/rubocop` clean; CI green across the Ruby matrix.

All of the above is met as of commit `e56e3f5`.

## Scope

**In scope:**

- The `github` formatter and its registration in `Formatters::FORMATS`
- `--help` text listing the new format
- Unit spec, registry spec, end-to-end `spec/exe` spec
- README "Output formats" entry and a new "Inline annotations on GitHub Actions" CI subsection
- CHANGELOG entry under `[Unreleased] / ### Added`

**Explicitly out of scope (do not widen without asking):**

- **Single-letter format abbreviations** (`-f g` → `github`, mirroring `rubocop -f g`). The user
  asked whether the command should mirror `bin/rubocop -f github`; it already does, because `-f` is
  the short form of `--format` and has been since #40. Abbreviations were discussed and recommended
  against — see **Decisions & Rationale**. The user has **not** yet answered whether to open a
  follow-up issue for them.
- Version bump, gemspec, or `Gemfile.lock` changes — correctly untouched for a feature branch.
- Any change to `text`, `json` or `rdjsonl` behavior. This is why the F21 security finding became
  issue #94 rather than a commit here — a complete fix has to touch `Base` and change all four
  formats.

## Completed Work

All items below are **verified** unless stated otherwise.

1. **`lib/fastererer/formatters/github_formatter.rb`** (new, 36 lines) — subclasses
   `Formatters::Base`. `render` calls `output_diagnostics` then puts one annotation per finding.
   Three private methods: `annotation`, `message`, `property`. (As of `e56e3f5`; the original
   commit also had `percent_encode`.)
2. **`lib/fastererer/formatters.rb:6,16`** — `require_relative` plus a `'github' => GithubFormatter`
   entry in `FORMATS`. The unknown-format error message derives from `FORMATS.keys`, so it updated
   itself.
3. **`lib/fastererer/cli.rb:13`** — new `FORMAT_HELP` constant, derived from
   `Formatters::FORMATS.keys` and `private_constant` as of `e56e3f5`.
4. **`spec/lib/fastererer/formatters/github_formatter_spec.rb`** (new) — eight contexts: multiple
   offenses, separators in a path, a control character in a path, a percent in a description, a
   comma and colon in a description, a control character in a description, no offenses, unparsable
   files.
5. **`spec/lib/fastererer/formatters_spec.rb`** — `fetch('github')` example; updated the
   unknown-format message expectation (required, since it derives from `FORMATS.keys`).
6. **`spec/exe/fastererer_spec.rb:106-112`** — end-to-end example through the real binary using
   `-f github`.
7. **README** — a `github` line in the "Output formats" block, a prose paragraph with a sample
   annotation, and a new "Inline annotations on GitHub Actions" subsection under CI integration
   covering the annotation cap and the reviewdog trade-off. Two new reference-link definitions.
8. **CHANGELOG** — `[#56]` entry under `[Unreleased] / ### Added`, plus the `[#56]` and
   `[GitHub Actions workflow commands]` link definitions.
9. **Commit `041d7fd`** — switched every runnable README example in "Output formats" and
   "CI integration" from `--format=<x>` to `-f <x>`, at the user's request. This touched the
   `json`/`rdjsonl`/`text` examples too, to keep the four-line code block internally consistent.
   **The user has not confirmed they want the non-`github` lines changed** — I offered to scope it
   back and they have not responded.
10. **Local review** — four specialist reviewers run in parallel; findings collated to
    `local-review.md`, then reconciled with per-finding status.
11. **Commit `e56e3f5`** — applied 11 review findings, all verified:
    - `property` now escapes through a single frozen `PROPERTY_ESCAPES` hash rather than chained
      `gsub` calls, removing the percent-first ordering constraint entirely. `percent_encode` is
      gone; `message` inlines its one `gsub`. (F4, resolving F13 and F20 with it.)
    - `spec/.../github_formatter_spec.rb` gained a control-character-in-**path** context (F25) and a
      comma/colon-stay-raw-in-the-message context (F9); `let(:lines)` renamed to `annotations` (F8).
    - `CLI::FORMAT_HELP` now derives from `Formatters::FORMATS.keys` and is a `private_constant`
      (F5, F6), so `--help` cannot drift from the registry.
    - `spec/exe/fastererer_spec.rb` asserts `start_with` instead of the verbatim `en.yml` string
      (F26).
    - README + CHANGELOG: corrected annotation-limit numbers and re-cited to GitHub's own docs
      (F10), softened the reviewdog claim (F11), documented that the example step exits `1` (F1),
      corrected where out-of-diff annotations render (F2), added the absolute-path warning (F22),
      restored alphabetical link ordering (F7).
12. **Issues #94 and #95 opened** for the two deferred findings.

**Provisional / worth knowing:** nothing in the implementation is a stub. The one known gap is
issue #94 — `Formatters::Base` emits attacker-controlled paths at the start of a line, which the
Actions runner will parse as a workflow command. It is deliberately not fixed on this branch
because the exposure is shared with `text`, `json` and `rdjsonl`.

## Current State

- **Working tree clean.** No modified, staged, or stashed changes.
- **Untracked files:**
  - `local-review.md` — this session's review output, reconciled: every finding carries a ✅ / ⏸️ /
    🚫 status. **Untracked and deletable**: `/ship-it` posts it to the PR and then offers to delete
    it. Its load-bearing conclusions are carried into **Decisions & Rationale** and **Insights &
    Learnings** below, so this handoff does not depend on it.
  - `.claude/commands/local-review.md` — **pre-existing before this session**, unrelated to this
    work. Do not sweep it into a commit.
- **Commits on this branch** (3, base `main`):
  - `d57165f` Add a github output format for Actions annotations
  - `041d7fd` Use the short -f flag in the README format examples
  - `e56e3f5` Escape github property values in a single pass
- **Pull request #93** — open, **draft**, no review decision, no comments and no reviews, assigned
  to the user, linked to close #56.
- **CI: all green** on run `33862415839` (commit `e56e3f5`) — `lint`, `rubocop`, `test (3.3)`,
  `test (3.4)`, `test (4.0)`.
- **No branch is in a broken or half-migrated state.** Nothing is outstanding on this branch.

## Environment & Setup

Nothing beyond a normal checkout. No services, migrations, seed data, feature flags or environment
variables are involved. This is a git worktree at `/Users/matt/code/fastererer2` — run everything
from there and do not `cd` to the original checkout.

## Key Files & Entry Points

Read in this order:

1. `lib/fastererer/formatters/github_formatter.rb:1-35` — the whole feature. `PROPERTY_ESCAPES`
   (line 10) plus `message` (line 25) and `property` (line 30) are the escaping; each does exactly
   one `gsub` pass over already-sanitized text.
2. `lib/fastererer/formatters/base.rb:7` (`UNSAFE_CHARS`), `:20` (`output_diagnostics`) and `:27`
   (`sanitize`). `output_diagnostics` is where the issue #94 fix goes. The tab exemption at `\x09`
   is deliberate and documented in the comment on line 6.
3. `lib/fastererer/file_traverser.rb:113` — `ErrorData#to_s`, which builds
   `"#{file_path} - #{error_class} - #{error_message}"`. The attacker-controlled path leads the
   line; this is the issue #94 payload.
4. `spec/lib/fastererer/formatters/github_formatter_spec.rb` — the unit spec, eight contexts.
   Compare against `rdjsonl_formatter_spec.rb` in the same directory, which it is modeled on.
5. `lib/fastererer/cli.rb:13-15` — `FORMAT_HELP`, derived from `Formatters::FORMATS.keys` and
   `private_constant`. The pattern to copy if a fifth format is ever added.
6. `local-review.md` (untracked, deletable) — all 30 findings with code snippets, reconciled so each
   carries a ✅ Fixed / ⏸️ Deferred / 🚫 Skipped status and the reason.

## Decisions & Rationale

- **The annotation message leads with the rule *key*, not the display name** (agent's judgment).
  Issue #56's template says `<rule>: <message>`, which in this codebase's JSON vocabulary would mean
  `rule_name`. The key was chosen instead for two reasons: it follows the precedent set deliberately
  in commit `2ef1f8c` ("Emit the rule key as the rdjsonl diagnostic code"), where the reasoning was
  that the key is the string a reader pastes into `.fastererer.yml` under `speedups:`; and it
  matches RuboCop's own `github` formatter, where the emitted cop name *is* the string you disable.
  Both reviewers who examined this agreed. Revisitable, but the rationale is recorded in the commit
  message and PR body.
- **Findings are emitted in traversal order, not sorted** (agent's judgment). `JsonFormatter` sorts
  by `[path, line]`; `RdjsonlFormatter` does not. The line-oriented streaming siblings set the
  precedent. The test reviewer confirmed this is unobservable at runtime because `FileTraverser`
  already walks files in sorted glob order and the analyzer walks the AST in source order.
- **`GithubFormatter`, not `GitHubFormatter`** (agent's judgment, endorsed by two reviewers).
  `GitHubFormatter` inflects to `git_hub_formatter.rb`, breaking the file-name convention, and the
  CLI value is `github` regardless. Prose in README and CHANGELOG correctly writes "GitHub".
- **Percent-encoding is layered on top of `Base#sanitize` rather than replacing it** (agent's
  judgment). GitHub's own escaping would encode CR/LF as `%0D`/`%0A`; `sanitize` instead renders
  them as literal `\x0A` text. Reusing `sanitize` keeps all four formatters consistent, and is safe
  because every rule description in `config/locales/en.yml` is single-line. Recorded so a future
  reader does not "fix" it toward `%0A`.
- **Property escaping is one `gsub` pass over a frozen hash, not chained `gsub` calls** (agent's
  judgment, breaking a tie between two reviewers; `e56e3f5`). The original chained form was correct
  only because percent-encoding ran first — encode `:` before `%` and a freshly written `%3A`
  becomes `%253A`. ruby-expert argued for keeping the chain because it makes that ordering visible
  on the page; code-best-practices argued for the hash. The hash won because a single pass never
  re-scans what it emits, so the invariant stops existing rather than being guarded by a spec that
  happens to catch violations. It also stranded `percent_encode` at one caller, which folded into
  `message` — resolving findings F13 and F20 at the same time.
- **The workflow-command injection became issue #94 rather than a commit on this branch** (agent's
  judgment, overruling the security reviewer's proposed scope). Their remediation overrode a
  `diagnostic_line` hook in `GithubFormatter` alone. But `Formatters::Base` is shared, and the
  default `text` format is worse off — an ordinary offense line already begins with the path, so
  `::stop-commands::x.rb:1: W: …` forges a command on **stdout** with no parse error required. A
  `github`-only patch would have closed a quarter of it while making the issue look resolved, and a
  complete fix has to change all four formats — which is out of scope for #56 and deserves its own
  `### Fixed` changelog entry. This repository squashes before merge, so bundling it would also have
  cost the security fix its own commit message.
- **Findings F19, F27 and F28 were skipped as the reviewers recommended** (agent's judgment):
  extracting a `::warning` constant is churn, pinning emission order guards behavior that cannot be
  observed, and the redundant statistics-line example names an intent cheaply.
- **Finding F3 became issue #95 rather than a commit** (agent's judgment, matching the reviewer's
  Defer). Emitting `title=` and the documentation URL changes the wire format; the format has not
  shipped in a release, so there is no compatibility cost to deciding it separately.
- **README examples use the short `-f` flag** (the **user's** call, 2026-09-04). Do not revert
  without asking. The user asked specifically for `-f github`; the sibling `json`/`rdjsonl`/`text`
  examples in the same code block were changed too, by agent judgment, to avoid a block mixing two
  spellings. That secondary decision was flagged to the user and is **unconfirmed** — see
  **Open Questions**.
- **Single-letter format abbreviations were recommended against** (agent's judgment, user has not
  ruled). RuboCop needs them because it ships ~17 formatters, and even then had to hand-assign them
  to resolve collisions (`[j]son` vs `[ju]nit`, `[p]rogress` vs `[pa]cman`). fastererer has four
  formats; prefix matching would break the first time a fifth format shares a leading letter, and it
  would cost the unknown-format error its precision, since that message is derived from
  `FORMATS.keys` and would need a separate ambiguous-prefix branch — each branch requiring its own
  example under the 100% branch floor.
- **`local-review.md` was assembled directly rather than via the documentation-expert agent**
  (agent's judgment). The `/local-review` command specifies delegating collation. There was no
  existing file to merge into, so a second agent pass would have shuttled roughly 15k tokens of
  review text to produce the same artifact.
- **Both High findings were independently verified before being acted on** (agent's judgment). The
  security finding's stderr reproduction was run locally, and the half that could not be tested
  locally — that the runner scans stderr — was checked against `actions/runner` source rather than
  accepted from the reviewer. The test finding's mutation was re-run after the fix to confirm the
  new example is the one that kills it. Worth repeating for any future review finding that would
  change code.

## Insights & Learnings

- **The Actions runner scans stderr for workflow commands, not just stdout.** Verified against
  `actions/runner` source: `ScriptHandler.cs` contains both
  `StepHost.OutputDataReceived += stdoutManager.OnDataReceived;` and
  `StepHost.ErrorDataReceived += stderrManager.OnDataReceived;`, feeding the same
  `ActionCommandManager`. This is not in GitHub's public workflow-command documentation, and it is
  the entire basis of issue #94 (finding F21 in the review). Any future work that routes text to
  stderr under Actions inherits
  this exposure.
- **`ActionCommandManager.TryProcessCommand` runs `TryParseV2(...) || TryParse(...)`** — the legacy
  V1 `##[cmd]` parser is still live. `ValidateStopToken` rejects only already-registered command
  names, empty strings, and `pause-logging`, so almost any token is accepted as a
  `::stop-commands::` sentinel.
- **The encode/decode ordering is the subtle correctness property of this formatter.** The runner
  decodes `%25` **last** (`UnescapeProperty`: `%0D → %0A → %3A → %2C → %25`), so an encoder that
  writes `%25` after writing `%3A` would double-encode: a real file named `a%3Ab.rb` must emit as
  `a%253Ab.rb` and decode back to `a%3Ab.rb`, not to `a:b.rb`. As of `e56e3f5` the formatter sheds
  the ordering question entirely by substituting in one pass
  (`github_formatter.rb:30-32`) — a single `gsub` never re-scans its own output. Keep it that way;
  reintroducing chained `gsub` calls reintroduces the hazard. The `'a,b:c%d.rb'` spec fixture is
  what would catch a regression.
- **Workflow-command forgery on stdout is not possible here,** because `TryParseV2` requires the
  line to start with `::` and splits the command block from the data at the *first* subsequent `::`.
  The message is the final segment, so an embedded `::error::` is inert text. Two reviewers
  attempted forgery independently against runner source; neither succeeded on stdout.
- **100% line-and-branch coverage did not catch a missing `sanitize` call.** Deleting `sanitize`
  from `property` (leaving it in `message`) passes all 341 examples at 100%/100%. Coverage proves a
  line executed, never that a result was depended upon. Mutation was the only technique that found
  it. This is worth remembering for any future `Base` helper reached from two call sites.
- **`.claude/agent-memory/` is gitignored** (`.gitignore:7`), so agent memory files written during a
  review cannot leak into this public repository. Checked during this session.
- **`Formatters::FORMATS` is now the single source of truth for format names everywhere.** Both
  `Formatters.fetch`'s unknown-format message and `CLI::FORMAT_HELP` derive from `FORMATS.keys` as
  of `e56e3f5`, so adding a fifth format updates `--help` and the error text with no further edit.
  Three of the four reviewers independently flagged the hand-maintained version (F6), which is a
  useful signal about how visible that class of duplication is.
- **`Style/MutableConstant` fires on an interpolated constant even under
  `# frozen_string_literal: true`.** The magic comment freezes literals, not interpolated strings,
  so RuboCop autocorrected `FORMAT_HELP` by appending `.freeze` to the adjacent-literal
  concatenation (`cli.rb:13-14`). Adjacent literals concatenate at parse time, so the `.freeze`
  correctly applies to the whole string, not just the second fragment.

## Constraints & Preferences

Given by the user during this session, beyond what `CLAUDE.md` already covers:

- **Prefer the `-f` short form in README examples** for the format flag (2026-09-04, explicit).

- **The user reviews recommendations before approving them.** When asked which review findings to
  apply, they declined the multiple-choice prompt with "I'll review them manually and then let you
  know what to fix", then asked "what do you recommend?" and approved the recommendation with "go
  ahead" (2026-09-04). Lead with a reasoned recommendation rather than an option menu.

Nothing else was corrected or ruled out. Two offers made during the session are still unanswered —
see **Open Questions**.

## Dead Ends

None. No approach was tried and abandoned; the implementation worked on the first pass and every
verification command has been green since.

Two things are **not pursued** rather than closed — forks in the road, not closed doors:

- **Emitting `title=<rule_name>` and the documentation URL in the annotation** — now issue #95. The
  `github` format remains the only one that discards `Finding#url`.
- **Neutralizing workflow-command openers across all formats** — now issue #94, with a verified
  reproduction in its description. The `github`-only variant the security reviewer proposed *was*
  considered and rejected; see **Decisions & Rationale**.

## Open Questions

**Non-blocking — awaiting the user, assumption made to keep moving:**

1. *"Want me to open a follow-up issue for single-letter format abbreviations, or drop it?"* — asked
   2026-09-04, unanswered. **Assumption:** dropped for now; nothing was opened. Revisit only if the
   user wants `-f g` parity with RuboCop.
2. *Should the README's `json`/`rdjsonl`/`text` examples keep the short `-f` form?* — the user asked
   only for `-f github`; commit `041d7fd` changed the sibling lines too, for block consistency, and
   the user was told this and offered a scope-back. **Assumption:** keeping all four short. If they
   say otherwise, revert only the three non-`github` lines in the "Output formats" block and the
   reviewdog example.
3. ~~**Which review findings to apply**~~ — **answered 2026-09-04.** The user asked for a
   recommendation and approved it: 11 findings applied in `e56e3f5`, F21 and F3 deferred to issues
   #94 and #95, F19/F27/F28 skipped. See **Decisions & Rationale**.

**Blocking:** none.

## Next Steps

The branch is complete. Nothing is required before review.

- [ ] 1. Confirm the user is satisfied with the README `-f` change scope (see **Open Questions**
      item 2), then mark PR #93 ready for review: `gh pr ready 93`
- [ ] 2. Optionally run `/ship-it`, which posts `local-review.md` and the durable sections of this
      handoff to PR #93 as collapsible comments and offers to delete both files
- [ ] 3. Once #93 merges, pick up issue #94 (workflow-command openers across all formats) — it is
      the highest-value follow-up and carries a verified reproduction in its description
- [ ] 4. Issue #95 (annotation `title=` / documentation URL) whenever the wire-format question is
      worth deciding

## Verification

Re-run on 2026-09-04, after the last edit (commit `e56e3f5`):

- `bin/rspec` — 343 examples, 0 failures; line coverage 801/801 (100.00%), branch coverage 202/202
  (100.00%) (2026-09-04)
- `bin/rubocop` — 85 files inspected, no offenses detected (2026-09-04)
- CI on PR #93, run `33862415839` — `lint`, `rubocop`, `test (3.3)`, `test (3.4)`, `test (4.0)` all
  pass (2026-09-04)
- **Mutation check for F25**: deleting `sanitize` from `GithubFormatter#property` fails exactly one
  example, `'with a control character in the path'`. Before `e56e3f5` the same mutation passed all
  341 examples at 100% line and branch. Re-run this if that spec is ever touched (2026-09-04)
- Manual: ran the binary over a fixture directory containing `we,ird:file.rb` and confirmed the
  separators encode to `%2C` and `%3A`; confirmed `-f bogus` still lists all four formats and
  exits `2` (2026-09-04)
- Manual: ran the binary over a directory containing `::stop-commands::tok.rb` and
  `a##[stop-commands]t.rb` (both unparsable) and confirmed stdout is clean while **stderr emits
  lines beginning with `::stop-commands::`** — this is the issue #94 reproduction (2026-09-04)

## References

- GitHub issue #56 — https://github.com/ExtractableMedia/fastererer/issues/56 — the originating
  issue; scope and the known annotation-cap limitation are in its description
- PR #93 — https://github.com/ExtractableMedia/fastererer/pull/93 — this branch, draft, no reviews
  yet
- GitHub issue #94 — https://github.com/ExtractableMedia/fastererer/issues/94 — workflow-command
  openers in output consumed by Actions; opened from this review, carries a verified reproduction
- GitHub issue #95 — https://github.com/ExtractableMedia/fastererer/issues/95 — carrying the rule
  name and documentation URL into annotations; deferred from this review
- GitHub issue #38 — https://github.com/ExtractableMedia/fastererer/issues/38 — the reviewdog
  integration this format is positioned against
- GitHub issue #40 — https://github.com/ExtractableMedia/fastererer/issues/40 — introduced
  `-f`/`--format` and the formatter infrastructure this builds on
- Workflow commands reference —
  https://docs.github.com/en/actions/reference/workflows-and-actions/workflow-commands — the format
  being emitted
- Checks API annotation limits — https://docs.github.com/en/rest/checks/runs — documents both "10
  warning annotations per step" and the 50-per-API-request cap; the README cites this as of
  `e56e3f5`
- `actions/runner` `ScriptHandler.cs` —
  https://github.com/actions/runner/blob/main/src/Runner.Worker/Handlers/ScriptHandler.cs — proves
  stderr is scanned for workflow commands
- `actions/runner` `ActionCommandManager.cs` —
  https://github.com/actions/runner/blob/main/src/Runner.Worker/ActionCommandManager.cs —
  `TryParseV2 || TryParse` and `ValidateStopToken`
- `2ef1f8c` — "Emit the rule key as the rdjsonl diagnostic code"; the precedent for leading the
  annotation message with the rule key rather than the display name
- `46e56b4` — "Add JSON and rdjsonl output formats"; established `Formatters::Base` and the
  stdout/stderr split this formatter reuses
- `local-review.md` (untracked, project root, **deletable by `/ship-it`**) — full text of all 30
  review findings with code snippets and per-reviewer rationale

## Resume Prompt

```text
Read github-annotations-format-HANDOFF.md in the project root. The branch is complete and PR #93
is ready to come out of draft; continue from "Next Steps". If #93 has already merged, start on
issue #94 instead.
```

## Handoff History

- **2026-09-04** — Initial handoff: `github` formatter implemented, committed (`d57165f`,
  `041d7fd`), draft PR #93 open and green on CI. Four-reviewer local review completed; 30 findings
  recorded in `local-review.md`, none applied. Two High findings outstanding (F21 stderr
  workflow-command injection, F25 untested `sanitize` call in `property`).
  Captured by Opus 5 (`claude-opus-5[1m]`)
- **2026-09-04** — Review reconciled: 11 findings applied in `e56e3f5` (single-pass property
  escaping, two new spec contexts, derived `--help`, six README/CHANGELOG corrections). F21 and F3
  deferred to issues #94 and #95. Suite 343 examples / 0 failures at 100% line and branch; CI green.
  Branch complete, PR #93 still draft. Captured by Opus 5 (`claude-opus-5[1m]`)
- **2026-09-04** — Explicit `/handoff` pass: no repository change since the previous entry.
  Refreshed the sections that `e56e3f5` had made stale — `Key Files & Entry Points` line references,
  the encode/decode insight (the ordering hazard is now designed out rather than guarded), and the
  `FORMATS` insight (`--help` now derives from the registry). Recorded the escaping tie-break, the
  issue #94 scope decision and the verify-before-acting practice under `Decisions & Rationale`.
  Verification re-run and unchanged. Captured by Opus 5 (`claude-opus-5[1m]`)
