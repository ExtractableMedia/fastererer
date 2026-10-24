# Local Review — `publish-it-command-rename`

## Review History

- **Initial review:** 2026-09-04 (F1–F18 added)
- **Amended:** 2026-09-04 (F19 added and fixed; F2, F7, F8, F17 revised after the user clarified
  that a new `/ship-it` will be created for commit cleanup, review posting and changelog upkeep)

**Change set:** commit `0882c5f` versus `main` — a `git mv` of `.claude/commands/ship-it.md` to
`.claude/commands/publish-it.md` (98% rename similarity) plus seven self-referencing line edits.

**Reviewers:** code-best-practices-reviewer, ruby-expert, security-reviewer, test-suite-architect.

**Bottom line:** nothing blocks merge. No reviewer returned a finding recommended **Implement**. All
five actionable findings are pre-existing properties of the runbook this branch only renamed, and
are recommended Defer or Skip. CI is green across all five checks.

---

## Findings

### F1 ℹ️ Observation - Rename is complete; no dangling references

**File:** `.claude/commands/publish-it.md`

A case-insensitive sweep for `ship[-_ ]?it` across the worktree — both `git grep` over tracked files
and plain `grep -r --exclude-dir=.git` to catch untracked and gitignored paths — returns zero hits.
All self-references were caught: the H1 (line 1), both `/tmp/publish-it-pr-body.md` paths
(lines 247, 250), the prepare-mode stop message (line 276), and the three example-session lines
(498, 515, 521).

Verified there is no user-level `~/.claude/commands/ship-it.md` that would have kept resolving and
masked a broken project-level reference. Nothing in the repo references `.claude/commands` from
Ruby, CI, or Rake, so the rename cannot break a path lookup in library or build code.

### F2 🟢 Low Priority - `/publish-it publish` stutters and `/publish-it prepare` reads oddly

**File:** `.claude/commands/publish-it.md` (lines 9–17)
**Recommendation:** Skip — the tension is strictly less than it was before the rename.

`/publish-it publish` is redundant, and `/publish-it prepare` reads as an instruction to publish
followed by an argument saying don't. It is sharpest at line 13, where `prepare` is described as
"No version bump, no tag, no publish" — a document titled **Publish It** whose first documented mode
disclaims publishing.

This is not new: `/ship-it prepare` under "Ship It" carried identical tension. The rename neither
creates nor worsens it, and lines 9–11 already supply the mitigating framing ("The two halves exist
so that merging work doesn't have to mean releasing it").

The rename is a net gain here. Line 17 documents the no-argument run as equivalent to `publish`;
under the old name a reader had to be *told* the default publishes, whereas now the filename and the
default mode agree.

If it ever bites in practice, the fix is renaming the *mode*, not the command (`prepare` / `release`)
— a larger, behavior-adjacent change that does not belong on this branch.

**Update after review:** this resolves itself. A new `/ship-it` is planned (F19) to own changelog
upkeep and merge-time workflow, so the `prepare` half is transitional. Once it migrates,
`/publish-it` is left doing only what its name says.

### F3 💡 Observation (optional action) - Example transcript still closes with "Shipped"

**File:** `.claude/commands/publish-it.md` (line 569)
**Recommendation:** Defer — cosmetic; fine as a one-line follow-up or fine to never do.

Raised independently by three reviewers. The final line of the `publish` example transcript reads
`🎉 Shipped v1.1.0!`. Unlike line 491 this is not prose *about* the command — it is a sample of the
completion message the command is instructed to emit, so it is the one remaining trace of the old
name in user-facing output. `🎉 Published v1.1.0!` would match line 562's
`✅ Gem fastererer 1.1.0 published to RubyGems` two lines above.

Deliberately not folded into this commit: it sits inside a fenced `text` block that no tooling
validates, and changing it would turn a provably-mechanical rename into a rename-plus-judgment-call.

### F4 ℹ️ Observation - Remaining generic "ship" prose correctly left alone

**File:** `.claude/commands/publish-it.md` (line 491)

"If `[Unreleased]` is empty after reconciliation, `publish` aborts early: there's nothing to ship" is
idiomatic English for "nothing to release" and reads fine. The three `ship` hits outside the command
file are unrelated generic usage and correctly untouched: `CHANGELOG.md:52` ("Prism ships with Ruby
itself"), `CHANGELOG.md:101` ("shipped in 0.10.1"), `.claude/agents/ruby-expert.md:58` ("it ships as
a performance tool").

### F5 ℹ️ Observation - Document is internally consistent under the new name

**File:** `.claude/commands/publish-it.md`

The header, Arguments block, Overview, all seven step headings, Interactive Confirmations and
Important Notes were read against the new name. The document's framing already led with publishing
before the rename — lines 3–5 describe the endpoint as "publish the gem to RubyGems and create the
matching GitHub Release", and 22 lines annotate steps with `*(publish)*`. The seven-item Overview
still matches the seven `### Step N` headings, and the prepare-stops-at-Step-4 claim matches the stop
instruction at line 276 that this commit edited.

### F6 ℹ️ Observation - The 13 over-length lines are provably pre-existing

**File:** `.claude/commands/publish-it.md`
**Recommendation:** Skip on this branch.

Lines exceeding the repo's 100-character wrap are byte-for-byte the same set as in `ship-it.md` at
`HEAD~1` — same 13 line numbers (12, 23, 77, 110, 138, 140, 141, 301, 316, 336, 460, 463, 483), same
lengths (101–102). The rename introduced none. The two lines it *did* lengthen land at 86 and 98
characters, under the limit.

Worth recording for future passes: a first count with `awk length` under the C locale reports bytes,
not characters, and this file is dense with em-dashes at 3 bytes each — that mixes real overruns with
false positives. Re-run under `LC_ALL=en_US.UTF-8` for character counts. These pass CI regardless,
since `.github/linters/.markdown-lint.yml` sets `MD013.line_length: 400`.

### F7 💡 Observation (optional action) - Untracked files are a `git grep` blind spot for renames

**File:** `.claude/commands/local-review.md` (untracked)
**Recommendation:** Defer — a process note, not a change to make in this diff.

`local-review.md:507` and `:509` reference `/ship-it`. They were initially retargeted to
`/publish-it` in the working tree and then **reverted** — see F19. Leaving the file untracked is
correct either way: it has never been committed, and CLAUDE.md's Review Scaffolding rule cuts
against volunteering it.

The failure mode worth naming: **`git grep` reports "no remaining `ship-it` references" while this
file still points at the old name**, because it is invisible to git. Any future rename under
`.claude/commands/` has the same trap. Verify with plain `grep -r --exclude-dir=.git`, not
`git grep`.

### F8 🟢 Low Priority - `local-review.md` cites posting mechanics that live in no current command

**File:** `.claude/commands/local-review.md` (line 509, untracked)
**Recommendation:** Defer — resolve when the new `/ship-it` is written; that command should own
these mechanics.

The parenthetical says `/ship-it` "(Step 7)" handles the posting mechanics and tells the reader to
reuse its `--body-file` pattern. This was already stale before this branch: the renamed file contains
**no** review-posting logic at all — `grep` for `local-review`, `DOC-REVIEW`, `PLAN.md` and `handoff`
across `publish-it.md` returns nothing. The citation described a `/ship-it` that this project never
had. Its `--body-file` pattern does exist, but at **Step 4** (`publish-it.md:247`), not Step 7, which
uses `--notes-file`.

This becomes correct once the planned `/ship-it` lands and takes on review-document posting.

### F9 🟡 Medium Priority - Predictable static `/tmp` filenames (CWE-377 / CWE-378)

**File:** `.claude/commands/publish-it.md` (lines 247, 250, 374–375, 392, 407, 426, 434, 448)
**Recommendation:** Defer — real, but requires local code execution as a prerequisite, and the fix
rewrites eight lines of shell across three steps. Out of scope for a rename; worth its own branch.

Three static paths are used — `/tmp/publish-it-pr-body.md`, `/tmp/release-notes.md`,
`/tmp/release-body.md`. None is created with `mktemp`, none under a `umask`-restricted private
directory, and there is no `rm`/`trap` cleanup anywhere in the file.

`/private/tmp` is `drwxrwxrwt`. The sticky bit prevents an attacker from *deleting* the user's file
but not from *pre-creating* the path. Two attack shapes, both requiring local code execution as any
user (a malicious dev-dependency install hook, a compromised local tool, a second account):

1. **Arbitrary file overwrite via symlink.** Line 374 is a plain `>` redirect with no `noclobber`, so
   a pre-planted symlink at `/tmp/release-notes.md` is followed and the target truncated. macOS has
   no `fs.protected_symlinks` equivalent. Same primitive at line 434.
2. **Attacker-controlled content reaching a public artifact.** `/tmp/publish-it-pr-body.md` is read
   back by `gh pr create --body-file` and `/tmp/release-notes.md` by `gh release create
   --notes-file`. Winning the write/read window means controlling the text of a public PR body or
   GitHub Release — a plausible vector for planting typosquat install instructions on a release page
   users trust.

Remediation, for whenever this is picked up — one private directory per run, mode 0700, with cleanup:

```bash
RUN_DIR=$(mktemp -d "${TMPDIR:-/tmp}/publish-it.XXXXXXXX")
trap 'rm -rf "$RUN_DIR"' EXIT
PR_BODY="$RUN_DIR/pr-body.md"
NOTES="$RUN_DIR/release-notes.md"
```

`mktemp -d` gives an unpredictable suffix and 0700 mode, defeating both pre-planting and the race;
the `trap` also resolves F10. Downstream references become `"$PR_BODY"` / `"$NOTES"`, matching the
file's existing already-quoted style.

### F10 🟢 Low Priority - Temp files are never cleaned up, and the footer is appended with `>>`

**File:** `.claude/commands/publish-it.md` (lines 407, 247, 250)
**Recommendation:** Defer — same branch and same fix as F9.

No step removes these files, so they persist between runs. Two consequences:

- Re-running Step 7 after a partial failure **appends the release-notes footer a second time** to a
  file that already has one, and that lands in a public release body.
- If the agent reaches `gh pr create` at line 247 without having executed the "Build
  `/tmp/publish-it-pr-body.md`" instruction at line 250, it silently publishes the *previous* run's
  PR body. That build step is prose rather than a code block, which makes it the most skippable
  instruction in the file.

Fully resolved by the `mktemp -d` + `trap` change in F9: a fresh directory per run cannot contain a
stale file.

### F11 🟢 Low Priority - `NEW_VERSION` validation is prose, not an enforced check

**File:** `.claude/commands/publish-it.md` (lines 150–163)
**Recommendation:** Skip — quoting is already correct throughout and the input source is the trusted
user; a guard here is defense against typos more than attack.

`NEW_VERSION` is the one free-form value flowing into shell. It is set from `AskUserQuestion` output
at line 151, then the `^\d+\.\d+\.\d+$` requirement is stated as a prose bullet at line 156 rather
than a runnable guard.

Impact is low for two verified reasons. A quoting audit across every code block found `$LAST_TAG`,
`$LAST_TAG_DATE`, `$NEW_VERSION`, `$BRANCH`, `$TITLE`, `$SHA`, `$RUN_ID`, `$PREV` and `$ARGUMENTS`
correctly double-quoted at every expansion site — no unquoted variables anywhere. The `<<EOF` heredoc
at line 407 is intentionally unquoted so `$PREV`/`$NEW_VERSION` expand, which is safe: heredoc
expansion is single-pass, so a `$(...)` or backtick inside a *variable's value* is not re-evaluated.
And the value's source is the user via `AskUserQuestion`, so the principal supplying it is the
principal being protected. The realistic failure is a malformed tag name, not code execution.

Optional hardening if the block is ever touched:

```bash
[[ "$NEW_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo "Invalid version: $NEW_VERSION"; exit 1; }
```

### F12 ℹ️ Observation - Preflight checks for `perl`, which the runbook never uses

**File:** `.claude/commands/publish-it.md` (line 56)
**Recommendation:** Defer — a one-word edit, but it belongs with a functional change, not a rename.

`command -v jq curl perl ruby` gates the release, and the doc says a missing tool "should abort here
rather than mid-release." No later step invokes `perl` — every text transform is `ruby -e` /
`ruby -i -pe`, deliberately so (lines 378 and 396 explain the avoidance of `awk` and dollar-digit
tokens). Net effect: a release aborts on a tool it does not need. Reads `command -v jq curl ruby`.

### F13 ℹ️ Observation - "`jq` is load-bearing in three later steps" overcounts

**File:** `.claude/commands/publish-it.md` (line 59)
**Recommendation:** Defer — pair with F12 when the file is next edited.

Of the five `jq` mentions after preflight, four are `gh --json … --jq`, which uses gh's *embedded* jq
engine and needs no binary on PATH. Only line 353 (`curl … | jq -r '.[0].number'`) requires the
installed `jq`. The check is still right to run; the justification is imprecise.

### F14 ℹ️ Observation - The RubyGems approval gate is verified intact

**File:** `.claude/commands/publish-it.md`, `.github/workflows/release.yml`

The diff touches no line in Step 6 or the Important Notes. All three reinforcing guardrails survive
verbatim: line 304 requires `AskUserQuestion` *before* the tag exists; lines 334–338 state "never
approve this gate on their behalf… The human review before the irreversible push to RubyGems is the
entire point of the gate"; lines 476–477 repeat it.

The runbook's claim is true of the actual workflow — `release.yml` declares `environment: rubygems`
with `id-token: write`, so the gate is enforced by GitHub, not merely by prose. There is no path to
an irreversible publish that bypasses both the `AskUserQuestion` and the environment review.

### F15 ℹ️ Observation - No sensitive content in the diff or commit message

**File:** commit `0882c5f`

Checked against patterns for tokens, API keys, credentials, internal hostnames, RFC1918 addresses and
ticket-ID shapes. Clean. The only URLs in the file are this repository, `rubygems.org` and
`keepachangelog.com` — all public and self-referential. No private repository names, internal systems
or ticket IDs. At 98% rename similarity the diff shows every changed line, so the rename is not
masking a content deletion. There is no `.claude/settings.json` in this repo, so no stale
permission-allowlist entry references the old name.

### F16 ℹ️ Observation - Coverage floors are structurally unaffected; no spec references the old name

**File:** `.simplecov`, `spec/`

`grep -rniE "ship[-_ ]?it" spec/` returns nothing. `.simplecov` scopes reporting to
`cover 'lib/**/*.rb'` with `enable_coverage :branch`, and gates the 100% line and branch minimums
behind `whole_suite`. Markdown under `.claude/` is outside `cover`, is not loadable Ruby, and is not
required at boot — it cannot enter the numerator or denominator of either metric. The floors are
numerically identical on this branch and on `main`.

`bin/rspec` was deliberately **not** run locally: no file SimpleCov measures, and no file the suite
loads, differs from `main`. CI ran the full suite on all three Ruby versions regardless.

The gemspec's `files` list is restricted to `lib/`, `exe/`, `config/` and three root docs, so
`.claude/` is not in the built gem either — the rename has zero packaging surface.

### F17 💡 Observation (optional action) - Global command files still reference `/ship-it` — leave them

**File:** `~/.claude/commands/handoff.md` (lines 44, 216), `~/.claude/commands/doc-review.md`
(line 285)
**Recommendation:** Skip — the references are still correct for other projects.

The test reviewer flagged these as dangling cross-references and recommended fixing them in a
separate pass. They are **not** dangling: 14 other projects on this machine still define their own
`.claude/commands/ship-it.md`. These global files are shared across all of them, so rewriting the
references would break `/handoff` and `/doc-review` everywhere except here.

Only `fastererer` renamed its command. The correct action is to leave the global files untouched —
and the planned new `/ship-it` (see F19) makes them correct for this project again as well.

### F18 ℹ️ Observation - No test harness for slash command files, and none should be built

**File:** `.claude/commands/`

`.claude/commands/*.md` is agent tooling: not required, parsed, or executed by the gem, and RSpec has
no reachable entry point into it. Building a Markdown link-checking harness to catch renames like
this one would add a maintenance surface far larger than the class of bug it prevents. Recorded as an
explicit decision not to propose one.

### F19 🟠 High Priority - Retargeting `local-review.md` at `/publish-it` was wrong; reverted

**File:** `.claude/commands/local-review.md` (lines 507, 509, untracked)
**Status:** Fixed — reverted to `/ship-it` in the working tree
**Recommendation:** Implement — done; the reference now points at the command that will own the
behavior.

During implementation both `/ship-it` references in this file were rewritten to `/publish-it` on the
assumption that the rename should propagate everywhere. That was a mechanical substitution applied
without checking what the reference *meant*.

It was wrong. These two lines describe **posting review findings as a PR comment**, and
`/publish-it` has no such capability — a `grep` across all 570 lines for `local-review`, `DOC-REVIEW`,
`PLAN.md` and `handoff` returns nothing. The rename would have left the file pointing at a command
that will never do the thing being described.

A new `/ship-it` is planned for this project, modeled on an existing implementation elsewhere, to
handle commit-message cleanup, posting the local-review document, and changelog updates. That is the
command these lines mean. Both references were reverted to `/ship-it` — a forward reference until the
new command lands, but pointed at the right owner.

The general lesson, and the reason this is rated High rather than Low: **a rename is not a
find-and-replace.** Each reference has to be read for intent. Here the same string `/ship-it` carried
two different meanings — the release runbook being renamed, and a review-posting workflow that was
never part of it.

---

## Consolidated Summary

| Finding | Priority | Category | Description | File | Recommendation | Status |
|---------|----------|----------|-------------|------|----------------|--------|
| F1 | ℹ️ Observation | Code Quality | Rename complete, no dangling refs | `publish-it.md` | — | — |
| F2 | 🟢 Low | Naming | `/publish-it publish` stutters | `publish-it.md` | Skip | 🚫 |
| F3 | 💡 Observation | Consistency | Transcript closes with "Shipped" | `publish-it.md:569` | Defer | ⏸️ |
| F4 | ℹ️ Observation | Consistency | Generic "ship" prose left alone | `publish-it.md:491` | — | — |
| F5 | ℹ️ Observation | Documentation | Internally consistent under new name | `publish-it.md` | — | — |
| F6 | ℹ️ Observation | Style | 13 over-length lines pre-existing | `publish-it.md` | — | — |
| F7 | 💡 Observation | Process | `git grep` blind to untracked files | `local-review.md` | Defer | ⏸️ |
| F8 | 🟢 Low | Documentation | Cites mechanics no current command has | `local-review.md:509` | Defer | ⏸️ |
| F9 | 🟡 Medium | Security | Predictable static `/tmp` paths | `publish-it.md` | Defer | ⏸️ |
| F10 | 🟢 Low | Correctness | No temp cleanup; `>>` double-appends | `publish-it.md:407` | Defer | ⏸️ |
| F11 | 🟢 Low | Security | `NEW_VERSION` guard is prose only | `publish-it.md:150` | Skip | 🚫 |
| F12 | ℹ️ Observation | Correctness | Preflight checks unused `perl` | `publish-it.md:56` | Defer | ⏸️ |
| F13 | ℹ️ Observation | Documentation | `jq` justification overcounts | `publish-it.md:59` | Defer | ⏸️ |
| F14 | ℹ️ Observation | Security | RubyGems gate verified intact | `release.yml` | — | — |
| F15 | ℹ️ Observation | Security | No sensitive content in diff | commit `0882c5f` | — | — |
| F16 | ℹ️ Observation | Testing | Coverage floors unaffected | `.simplecov` | — | — |
| F17 | 💡 Observation | Process | Global `/ship-it` refs stay valid | `~/.claude/commands/` | Skip | 🚫 |
| F18 | ℹ️ Observation | Testing | No command-file harness, by choice | `.claude/commands/` | — | — |
| F19 | 🟠 High | Correctness | Reference retargeted at wrong command | `local-review.md:507` | Implement | ✅ |

**19 findings — 6 actionable (1 Implement/fixed, 3 Defer, 2 Skip), 13 observations.**

---

## Pre-Merge Checklist

Nothing on this list blocks the merge. F19 was found and fixed during review; every remaining
actionable finding is a pre-existing property of the runbook that this branch only renamed.

- [x] F19 - Revert `local-review.md` references to `/ship-it` (fixed) ✅
- 🚫 F2 - `/publish-it publish` stutter (skipped — tension is strictly less than before the rename)
- ⏸️ F8 - Cites posting mechanics no current command has (deferred — resolve with the new `/ship-it`)
- ⏸️ F9 - Predictable static `/tmp` paths (deferred — own branch; `mktemp -d` + `trap`)
- ⏸️ F10 - No temp cleanup, `>>` double-appends footer (deferred — same fix as F9)
- 🚫 F11 - `NEW_VERSION` guard is prose only (skipped — quoting correct, input source trusted)

---

## Positive Feedback

- **A pure rename kept pure.** True `git mv` at 98% similarity: 7 lines changed out of 570, no
  incidental reflow, no opportunistic cleanup riding along. Git records it as a rename, so
  `git log --follow` keeps the file's history and reviewers see a 7-line diff instead of a 570-line
  delete-plus-add.
- **Reasoning parked in the commit message, not the file.** The body explains why "ship it" was the
  wrong word and why the filename is load-bearing — exactly what CLAUDE.md says belongs in a commit
  rather than a code comment.
- **No changelog entry, correctly.** The two prior `.claude/`-only commits (`441389c`, `f7b3e9b`)
  added none either; the changelog tracks the gem, not local tooling.
- **The release runbook was verified by execution, not by reading.** The version constant loads
  (`1.1.0`), `Gemfile.lock` confirms the gem as its own path dependency, the Step 7 changelog
  extraction produces the correct `[1.1.0]` body, `git describe --tags --abbrev=0 "v1.1.0^"` resolves
  to `v1.0.0`, and the lightweight-tag parenthetical is accurate (`v0.12.0` is the sole non-annotated
  tag of 37).
- **Scope discipline held under temptation.** Thirteen over-length lines and two stale preflight
  checks were found and deliberately left for a branch where they belong.
