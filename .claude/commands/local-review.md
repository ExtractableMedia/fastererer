# Local Review

## Parameters

If the user provided additional context: `$ARGUMENTS`

Parse `$ARGUMENTS` for the following flags. Flags can be combined.

### `--plan`

Review an implementation plan instead of code changes. This changes the review
mode entirely — reviewers evaluate the **plan document** rather than a change
set.

**Plan file resolution:**

1. If a `PLAN.md` file exists in the repository root, use that.
1. Otherwise, check `~/.claude/plans/` for the most recently modified `.md`
   file in the current project's plans directory and use that.
1. If no plan file is found, inform the user and abort.

**Reviewer behavior in plan mode:**

- Each specialist reviewer receives the plan content and evaluates it from
  their domain perspective.
- Reviewers should assess: completeness, correctness, potential pitfalls,
  missing considerations, and whether the approach aligns with codebase
  patterns.
- Reviewers should read the files referenced in the plan to verify the plan's
  assumptions are accurate (e.g., that the code the plan describes modifying
  actually exists and works the way the plan assumes).
- Findings use the same severity indicators and numbering scheme (F1, F2, ...)
  as code review findings.
- The output file is still saved to `local-review.md` with a heading that
  indicates this is a **plan review** (e.g., "Plan Review" instead of "Local
  Review"). The same Merging with Existing Findings rules apply — if
  `local-review.md` already exists from a prior code or plan review, the
  documentation-expert merges findings rather than overwriting the file.
- Skip the Interactive Finding Selection step — plan reviews are informational
  and findings are addressed by revising the plan, not by fixing code.

**Which reviewers to invoke in plan mode:**

Invoke the same reviewers as for code reviews, but base the decision on what the
plan **describes modifying** rather than which files have actually changed.
Always invoke code-best-practices-reviewer, ruby-expert, security-reviewer, and
test-suite-architect.

### `--reconcile`

Assess the current state of findings in `local-review.md` and mark completed
items. This does **not** re-run the review — it evaluates whether existing
actionable findings have been addressed in the code.

**Behavior:**

1. Read the existing `local-review.md`. If it doesn't exist, inform the user
   and abort.
1. For each **open actionable finding** (🔴🟠🟡🟢 without a status marker):
   - Read the file and line(s) referenced in the finding.
   - Determine whether the issue described has been resolved in the current
     code (e.g., the suggested fix was applied, the code was rewritten, or the
     referenced code no longer exists).
   - If resolved: mark the finding as ✅ Fixed, following the status tracking
     conventions in the Output Requirements section below. Include a brief
     explanation of how it was addressed (e.g., "Fixed — validation added in
     commit `abc123`" or "Fixed — method was refactored").
   - If not resolved: leave the finding unchanged.
1. Update the pre-merge checklist and consolidated summary table to reflect
   the new status of any findings that were marked fixed.
1. Save the updated `local-review.md`.
1. Output a summary of what changed (e.g., "Marked F1, F3, F5 as fixed.
   2 findings remain open: F2, F4.").

**Important:** Do not re-evaluate the severity or content of findings. Do not
add new findings. Do not remove findings. Only update the status of findings
that have been addressed. Skip findings already marked 🚫 Ignored or
⏸️ Deferred — their status was explicitly set and should only be changed by
the user.

### Default behavior (no flags)

If `$ARGUMENTS` does not contain `--plan` or `--reconcile`, run the standard
code review as described below.

---

## Change Set

> **Note:** In `--plan` mode the change set is not used — reviewers analyze
> the plan document instead. See the `--plan` parameter above.

The **change set** defines which changes the reviewers should analyze.

- If `$ARGUMENTS` (excluding any flags parsed above) specifies a change set
  (e.g., a commit range, specific files, or a description of what to review),
  use that as the change set.
- Otherwise, the default change set is **the changes on this branch** (i.e., all
  commits on the current branch that are not on the base branch).

All reviewer instructions below refer to "the change set" — this always means
the change set determined above.

---

## Reviewer Instructions

Every reviewer must do three things for each finding, not just describe it:

1. **Describe the finding** — what the issue is and where.
1. **Assign a severity** (🔴🟠🟡🟢, or ℹ️/💡 for observations) — how much the
   issue matters in principle.
1. **Give an implementation recommendation** — a frank judgment on whether the
   change is actually worth making *for this change set*, independent of its
   severity.

Severity and recommendation are different axes: severity measures how much the
issue matters; the recommendation measures whether acting on it *now* is worth
the cost. The recommendation exists to guard against **premature optimization**
and **unnecessary polishing**. A finding can be technically valid yet not worth
implementing — a DRY extraction with only two call sites, a speculative
performance tweak with no measured bottleneck, a refactor whose churn outweighs
the readability gain. Reviewers should say so plainly rather than implying every
finding must be fixed. Use one of:

- **Implement** — worth doing in this change set; benefit clearly exceeds cost.
- **Defer** — legitimate, but better as a follow-up (out of scope, needs a
  broader change, or not urgent).
- **Skip** — not worth doing; the cost (churn, indirection, risk) outweighs the
  gain. Prefer this over a half-hearted "could fix" when the value is marginal.

State the recommendation with a one-line rationale. When severity and
recommendation diverge — a 🟢 Low recommended **Skip**, or a 🟡 Medium
recommended **Defer** — that divergence is the useful signal; surface it rather
than smoothing it over.

### Code Best Practices

Instruct code-best-practices-reviewer to analyze the change set. This should include:

- **Code organization** — Proper separation of concerns, single responsibility,
  appropriate abstraction levels
- **Naming and clarity** — Descriptive variable/method names, self-documenting
  code, clear intent
- **DRY violations** — Duplicated logic that should be extracted
- **Complexity** — Overly complex conditionals, deep nesting, methods that do
  too much
- **Error handling** — Appropriate exception handling, edge case coverage

### Ruby Expert

Instruct ruby-expert to analyze the change set. This should include:

- **Idiomatic Ruby & object design** — POODR principles, single responsibility,
  composition over inheritance, value objects, narrow error handling
- **Prism AST traversal** — Correct visitor/`visit_*` recursion, matching the
  right node types (e.g. `CallNode` and its safe-navigation flag, `ForNode`,
  block/symbol-to-proc shapes), accurate location reporting, resilience to
  partial parses
- **Scanner & rule design** — One check per scanner, registration through the
  rule catalog with a stable rule name and explanation, separation of detection
  from output, controlling false positives vs false negatives
- **Gem packaging** — `fastererer.gemspec` correctness, `required_ruby_version`,
  the version constant and `Gemfile.lock` moving together, `exe/` executable
  hygiene and exit codes
- **Performance** — The analyzer must be fast itself: watch allocations in hot
  traversal paths, prefer lazy/streaming over large intermediates, optimize only
  measured bottlenecks

### Security

Instruct security-reviewer to perform a security audit of the change set. This
is a CLI tool that parses **untrusted Ruby source**, so the threat model is a
parser/command-line tool, not a web app. This should include:

- **Untrusted input handling** — The analyzer must never `eval`, `require`, or
  otherwise execute the source it inspects; parsing is the only safe operation
- **Denial of service** — Catastrophic regex backtracking (ReDoS), unbounded
  recursion on deeply nested ASTs, or pathological files that exhaust memory
- **Filesystem safety** — Path traversal when resolving/globbing target files,
  following symlinks, honoring config without escaping the project root
- **Command & argument injection** — Shelling out (`system`, backticks,
  `Open3`) with unsanitized paths or CLI arguments
- **Information exposure** — Leaking absolute paths, environment, or file
  contents in error messages and backtraces
- **Supply chain** — Dependency and gemspec hygiene (`rubygems_mfa_required`,
  pinned/locked versions, no unexpected runtime dependencies)

### Test Coverage

Instruct test-suite-architect to analyze the change set and provide recommendations for test
coverage. This should include:

- **Missing tests** — New code paths, edge cases, or functionality that lack
  test coverage
- **Tests to update** — Existing tests that may need modification due to
  changed behavior
- **Tests to remove** — Obsolete tests for removed functionality or redundant
  coverage
- **Test quality concerns** — Brittle tests, improper mocking, or tests that
  don't actually verify behavior

## Collation and Assembly

After all specialist reviewers have completed their analyses, forward their
individual review results to the **documentation-expert** agent for collation
and assembly into the final `local-review.md` document.

The documentation-expert is responsible for:

1. **Receiving all individual reviews** — Collect the full output from each
   specialist reviewer (code best practices, Ruby expert, security, and test
   coverage)
1. **Assigning finding numbers** — Apply a single global numbering scheme
   (F1, F2, F3, ...) across all reviewers in the order findings appear
1. **Assembling the document** — Combine all findings into a unified document
   following the Documentation Format conventions below
1. **Merging with existing findings** — If `local-review.md` already exists in
   the repository root, read it first and merge new findings with existing
   ones (see Merging with Existing Findings below)
1. **Building the consolidated summary** — Create the summary table and
   pre-merge checklist from all findings
1. **Writing the file** — Save the assembled document to `local-review.md` in
   the repository root
1. **Not running `/doc-review` on the output** — The documentation-expert must
   **not** invoke `/doc-review` (or otherwise produce a review of the
   `local-review.md` file itself) as part of `/local-review`. The file is the
   *output* of a review pipeline, not project documentation, and a meta-review
   of it adds noise without value. Only run `/doc-review` against
   `local-review.md` if the user explicitly asks for it in a later turn.

## Documentation Format

When documenting the local review, follow these conventions:

### Severity Indicators

Use emoji indicators for quick visual scanning of issue severity:

**Actionable findings** (require attention):

- 🔴 **Critical** — Must fix before merge (security vulnerabilities, data
  loss, breaking changes)
- 🟠 **High Priority** — Should fix before merge (bugs, missing tests,
  performance issues)
- 🟡 **Medium Priority** — Should address (code quality, accessibility,
  consistency)
- 🟢 **Low Priority / Nice-to-Have** — Can address later (minor improvements,
  future enhancements)

**Observations** (not required for merge — never appear in the pre-merge
checklist):

- ℹ️ **Observation** — Pure commentary. Highlights a good pattern, a positive
  practice, an architectural note, or a deliberate decision worth recording
  (including a note on why a tempting change was *not* made). There is nothing
  to act on.
- 💡 **Observation (optional action)** — Surfaces a latent improvement a reader
  *could* act on but that sits below the 🟢 Low actionable bar (e.g. a more
  intention-revealing refactor, a minor asymmetry). Noted so the option is
  visible — not to imply it should be done; skip it unless trivially worthwhile.

Keep these two kinds distinct: a reader scanning observations should be able to
tell at a glance which are "nice work, nothing to do" (ℹ️) and which carry a
"here is a thing you *could* change" (💡).

### Numbered Findings

**All findings must be numbered sequentially** for easy reference in discussions:

- Use a single global numbering scheme across all reviewers (e.g., F1, F2, F3)
- Number findings in the order they appear, starting with the first reviewer
- Reference findings by number in the consolidated summary table
- Use the format: `### F1 🟡 Medium Priority - Description`

**Important:** Use `F1`, `F2`, etc. instead of `#1`, `#2` to avoid GitHub
auto-linking finding numbers to unrelated issues/PRs.

Example:

```markdown
### F1 🟡 Medium Priority - Missing input validation

**File:** `app/controllers/users_controller.rb` (line 45)
**Recommendation:** Implement — unvalidated input reaches a DB write; low cost.
...

### F2 🟢 Low Priority - Consider extracting method

**File:** `app/models/user.rb` (line 120)
**Recommendation:** Skip — only two call sites; extracting adds indirection for
no real DRY win.
...

### F3 ℹ️ Observation - Clean use of service objects

**File:** `app/services/payment_processor.rb`
...

### F4 💡 Observation (optional action) - `reject` would read clearer than the nil-map

**File:** `app/models/user.rb`
Filtering the node before mapping would be more intention-revealing than mapping
to `nil` and relying on a downstream guard. Correct as-is; optional.
...
```

Every actionable finding (🔴🟠🟡🟢) must carry a **Recommendation** line
(Implement / Defer / Skip + one-line rationale). ℹ️ observations carry no
recommendation; 💡 observations state the optional action inline.

### Actionable Feedback

- Include **code snippets with fixes** — don't just describe the problem, show
  the solution
- Reference specific file paths and line numbers
- Explain *why* something is an issue, not just *what* is wrong
- Include a **Recommendation** (Implement / Defer / Skip) with a one-line
  rationale, so the reader knows whether the fix is worth making — not merely
  that it is possible

### Consolidated Summary

At the end of the review, provide a **summarized list across all reviewers** with:

- **Finding number** (e.g., F1, F2) for cross-referencing
- Item description
- Priority level (Critical/High/Medium/Low)
- Category (Security, Performance, Code Quality, Parsing, Testing, etc.)
- Recommendation (Implement / Defer / Skip; — for observations)

Example table format:

```markdown
| Finding | Priority | Category | Description | File | Recommendation |
|---------|----------|----------|-------------|------|----------------|
| F1 | 🟡 Medium | Code Quality | Missing validation | `users_controller.rb` | Implement |
| F2 | 🟢 Low | Performance | Consider caching | `api_client.rb` | Skip |
| F3 | ℹ️ Observation | Code Quality | Clean service objects | `payment_processor.rb` | — |
```

This allows developers to quickly see all action items and reference specific
findings by number in discussions or commits. Observations appear in the table
for completeness but are visually distinct from actionable findings.

### Pre-Merge Checklist

Convert **actionable findings only** (🔴🟠🟡🟢) into a concrete checklist.
Do **not** include ℹ️ or 💡 Observation findings in the checklist — neither
requires action. Do **not** include generic "run tests" or "run linting"
items — the full test suite runs on CI automatically.

```markdown
- [ ] Fix critical issue X
- [ ] Address high priority issue Y
```

Use the leading column as a pre-cognitive status indicator (see Tracking Finding
Status): `- [ ]` open, `- [x] … ✅` fixed, `- 🚫 …` ignored, `- ⏸️ …` deferred.

### Positive Feedback

Use ℹ️ **Observation** findings to highlight what the change set does well —
good patterns, clean architecture, or thoughtful design decisions. These
numbered observations provide balance and reinforce good practices while
remaining easy to reference in discussions. Reserve 💡 **Observation (optional
action)** for the separate case where something works but a small, optional
improvement is available — keep genuine praise (ℹ️) distinct from latent
suggestions (💡) so neither drowns out the other.

## Output Requirements

### Tracking Finding Status

When **actionable** findings have been addressed, mark them visually to show
progress while preserving the original content of each finding for reference.
ℹ️ and 💡 Observation findings do not require status tracking.

**Status indicators:**

- ✅ **Fixed** — The issue has been resolved in code
- 🚫 **Ignored** — Explicitly decided not to address (include reason)
- ⏸️ **Deferred** — Will address in a future PR or later

**How to mark fixed findings:**

Apply strikethrough to the finding heading (excluding the finding number) and
add the green ✅ icon to the right. Do **not** delete the finding content —
preserve it for reference.

```markdown
### F1 ~~🟡 Medium Priority - Missing input validation~~ ✅ Fixed

**File:** `app/controllers/users_controller.rb` (line 45)
**Status:** Fixed in commit `abc123`
...original finding content preserved...
```

In the pre-merge checklist, **check the box** for fixed findings and include
a brief explanation:

```markdown
- [x] F1 - Fix input validation (fixed) ✅
```

**How to mark ignored, skipped, or deferred findings:**

Apply strikethrough to the finding heading (excluding the finding number) and
add the appropriate status icon to the right. Do **not** delete the finding
content — preserve it for reference.

```markdown
### F2 ~~🟢 Low Priority - Consider extracting method~~ 🚫

**File:** `app/models/user.rb` (line 120)
**Status:** Ignored — complexity not warranted for a single call site
...original finding content preserved...
```

```markdown
### F3 ~~🟡 Medium Priority - Add caching layer~~ ⏸️

**File:** `app/services/api_client.rb` (line 88)
**Status:** Deferred to follow-up PR
...original finding content preserved...
```

In the pre-merge checklist, **replace the checkbox with a status glyph** for
ignored, skipped, or deferred findings — `🚫` for ignored, `⏸️` for deferred —
so status reads from the leading column without parsing the suffix:

```markdown
- 🚫 F2 - Extract method (ignored — single call site)
- ⏸️ F3 - Add caching (deferred to follow-up PR)
```

In the consolidated summary table, add a Status column after Recommendation.
Recommendation and Status tell a coherent story (Implement → ✅, Defer → ⏸️,
Skip → 🚫):

```markdown
| Finding | Priority | Category | Description | File | Recommendation | Status |
|---------|----------|----------|-------------|------|----------------|--------|
| F1 | 🟡 Medium | Code Quality | Missing validation | `users_controller.rb` | Implement | ✅ |
| F2 | 🟢 Low | Code Quality | Extract method | `user.rb` | Skip | 🚫 |
| F3 | 🟡 Medium | Performance | Add caching | `api_client.rb` | Defer | ⏸️ |
| F4 | ℹ️ Observation | Code Quality | Clean service objects | `payment_processor.rb` | — | — |
```

### File Output

Save the complete review findings to `local-review.md` in the repository root.
The **documentation-expert** agent is responsible for creating and updating
this file.

- **Create** the file if it doesn't exist
- **Merge** with existing findings if the file already exists (see below)
- Include all sections: individual reviewer findings, consolidated summary,
  pre-merge checklist, and positive feedback

### Merging with Existing Findings

When `local-review.md` already exists, the **documentation-expert** must:

1. **Read the existing file first** — understand current findings and their
   status
1. **Preserve existing finding numbers** — don't renumber resolved findings
1. **Preserve status markers** — keep ✅ Fixed, 🚫 Ignored, ⏸️ Deferred markers
   and their associated content intact
1. **Add new findings** — with the next sequential number (e.g., if F1–F4
   exist, new findings start at F5)
1. **Update findings** — if re-review shows they're now resolved or still
   present
1. **Strike through findings** — that are no longer applicable (e.g., the code
   they referenced has been deleted or completely rewritten) — do **not**
   remove them; apply strikethrough and add a brief explanation of why
1. **Update the review date** — at the top of the document

Example workflow for subsequent reviews:

```markdown
## Review History
- **Initial review:** YYYY-MM-DD
- **Re-review:** YYYY-MM-DD (findings F1, F3 fixed; F5–F6 added)
```

### Session Output

After saving the file, output the **complete review findings** in the Claude
session. This should include:

1. **All individual reviewer findings** — Full details from each specialist
   reviewer (code best practices, Ruby expert, security, and test coverage)
1. **Consolidated summary table** — All issues with priority and category
1. **Pre-merge checklist** — Actionable items organized by priority
1. **Positive feedback** — What the PR does well

The session output should mirror the content saved to `local-review.md` so the
developer can review findings directly in the terminal without opening the file.

**Important:** Use the same finding numbers (F1, F2, etc.) in both the file and
session output. This enables easy reference like "let's fix F3 first" or
"commit message: addresses local review F1 and F2".

### PR Comment Format

When posting review findings as a PR comment (e.g., during `/ship-it` or when
explicitly asked), use the collapsible `<details><summary>` format. The
`/ship-it` command (Step 7) handles the posting mechanics — use its
`--body-file` pattern to avoid heredoc quoting issues.

The comment should have this structure:

- **Heading**: `## Local Review — [status summary]`
- **Stats line**: `**[N findings — X actionable, Y observations]**`
- **Body**: Full review content inside a `<details>` block

The `<summary>` line should include the total finding count and a breakdown
(e.g., "12 findings — 3 fixed, 5 actionable, 4 observations"). When all
actionable findings have been addressed, lead with that:
"12 findings — 8 fixed, 4 observations — all clear".

### Interactive Finding Selection

After displaying all review output, present the list of **actionable findings
only** (🔴🟠🟡🟢 — not ℹ️ or 💡 observations), formatted as:

```text
F1 🔴 Critical - Description (file.rb)
F3 🟡 Medium - Description (file.rb)
F5 🟢 Low - Description (file.rb)
```

Ask the user which findings to fix. Accept finding numbers (e.g., "F1, F3"),
"all", or "skip". If the user selects one or more findings, begin fixing them
in order.
