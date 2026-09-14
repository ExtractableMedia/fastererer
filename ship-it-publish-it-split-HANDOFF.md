# Handoff: Split `/publish-it` into `/ship-it` (branch prep) and `/publish-it` (release only)

**Status:** Ready for review **Created:** 2026-09-04 **Updated:** 2026-09-04 **Branch:**
`ship-it-command-and-publish-it-simplification` (base: `main`) **Pull request:**
https://github.com/ExtractableMedia/fastererer/pull/97 (draft) **Issues:** none — checked
`closingIssuesReferences`, the pull request body and all commit trailers **Captured by:** Opus 5
(`claude-opus-5[1m]`)

## Start Here

This branch splits one slash command into two. `/publish-it` used to carry a `prepare` mode
(reconcile the changelog against merged pull requests) and a `publish` mode (do that, then cut the
release); the `prepare` half became a new `/ship-it` that prepares a feature branch for merge and
records its changelog entry while the work is fresh. Both files are agent-executed runbooks under
`.claude/commands/` — no Ruby, spec or workflow file is touched anywhere on this branch.

The work is complete and reviewed. Two commits are pushed, all five CI checks pass, and
`/local-review` found 27 findings of which 18 are fixed. **The first action is to decide whether to
mark pull request
#97 ready for review** — it is still a draft. Nothing is half-finished.

State below was accurate at capture. Re-verify before trusting it:

```bash
git status --short --branch
git --no-pager log --oneline -5
```

## Objective

The user's request, verbatim:

> Create a branch to simplify the /publish-it command to remove the prepare/publish options and to >
create a new /ship-it command that matches more similar to what the Alice codebase's version does >
(for the items that are relevant in this codebase). For example, cleaning up the commit messages, >
posting the local-review / plan / handoff documents to the PR, updating the changelog (note that >
the changelog should only contain end-user-facing changes), etc. Extract the items from >
`/publish-it prepare` to the /ship-it command where it makes sense, as /publish-it should be just >
for publishing a new version of the gem now. Make sure both markdown files (publish-it.md and >
ship-id.md are utilizing the full 100 character line length, but do not exceed 100 characters per >
line).

Acceptance criteria: `/publish-it` has no mode arguments and only cuts releases; `/ship-it` exists
and covers commit-message cleanup, artifact posting and changelog upkeep; the changelog rule is
end-user-facing changes only; both files use the full 100-character width without exceeding it.

## Scope

**In scope:** the two files under `.claude/commands/`, plus a `local-review.md` produced by the
review pass.

**Explicitly out of scope**, decided during the session:

- **Linear sync.** The source implementation has a step for it. This repository has no Linear
  references anywhere in its history, and its `CLAUDE.md` forbids naming internal ticket IDs in a
  public repository. Left out; the user was told and did not object.
- **`PLAN.md` history rewriting.** The source implementation strips `PLAN.md` from branch history
  with `git filter-branch`, because a `/start-work` command commits it as the branch's first commit.
  This repository has no such command and never commits a plan, so the whole mechanism is
  unnecessary.
- **Ruby, spec, gemspec and workflow files.** Untouched by design.

## Completed Work

1. **`.claude/commands/ship-it.md` created** (794 lines, new file). Ten steps: rebase onto
   `origin/main`; identify commits; review each commit's diff against its message; reword via
   `amend!` plus a non-interactive autosquash; run the suite and linter; push; create or update the
   pull request; write the changelog entry; post review artifacts; confirm. **Written, not
   executed** — the command has never been run end to end.
2. **`.claude/commands/publish-it.md` rewritten** (546 lines, was 570). The `## Arguments` section,
   all ten `*Runs in: …*` annotations, the `changelog-catch-up` branch and one of the two example
   workflows are gone. Its Step 1 changelog reconcile survives as a safety net. **Written, not
   executed.**
3. **Both files moved to a `mktemp -d` scratch directory** instead of fixed `/tmp` paths, closing a
   CWE-377/378 finding raised in the previous branch's review.
4. **Review fixes applied** in commit `a5022b8` — 18 of 27 findings. See **Decisions & Rationale**
   and `local-review.md`.
5. **Both files wrapped to exactly 100 characters**, verified with a character-aware tool.

Provisional / worth knowing: the example transcripts in both files are illustrative, not captured
from real runs. The finding counts and example numbers in them are invented.

## Current State

- **Branch:** `ship-it-command-and-publish-it-simplification`, pushed, in sync with its upstream.
- **Commits:**
  - `583c05b` Split branch preparation out of /publish-it into a new /ship-it
  - `a5022b8` Harden the artifact posting and add a verification gate
- **Pull request #97:** open, **draft**, no review decision yet, no linked issues.
- **CI:** all five checks pass on `a5022b8` — `lint`, `rubocop`, `test (3.3)`, `test (3.4)`,
  `test (4.0)`.
- **Working tree:** clean of tracked modifications. Three untracked files:
  - `local-review.md` — this branch's review, 27 findings. **Untracked and deletable**; `/ship-it`
    Step 9 would post and remove it. Its load-bearing content is carried in this file.
  - `local-review-publish-it.md` — the *previous* branch's review (pull request #96), which the user
    renamed from `local-review.md` so this branch could start a fresh one. Not this branch's work.
  - `.claude/commands/local-review.md` — the user's `/local-review` command, deliberately untracked
    across many sessions. **Do not `git add` it.** One line was edited this session (see below).
- No stashes, no worktrees created, no branches beyond this one.

## Environment & Setup

- Local Git is **2.55.0** — exactly the floor for `git history fixup`, which `/ship-it` Step 8
  offers. Anyone on 2.54 or earlier gets `git: 'history' is not a git command` and must use the
  documented `git commit --fixup` fallback.
- `gh` 2.100.0, authenticated.
- This checkout is a **git worktree** (`/Users/matt/code/fastererer2`), not the main checkout. The
  stash stack is shared with every other worktree — never use a bare `git stash` here.

## Key Files & Entry Points

1. `.claude/commands/ship-it.md:20` — "The squash message is what lands". Read this before anything
   else in the file; two later steps depend on the reader already holding it.
2. `.claude/commands/ship-it.md:34` — the scratch-directory contract, including why `trap … EXIT`
   cannot work here.
3. `.claude/commands/ship-it.md:438` — Step 9, the artifact posting. Most of the review findings
   landed here.
4. `.claude/commands/publish-it.md:92` — Step 1, the changelog reconcile, now framed as a safety net
   rather than the normal route.
5. `local-review.md` — all 27 findings with their status. **Untracked and deletable**; the
   conclusions that matter are reproduced in this file so nothing is lost if it goes.

## Decisions & Rationale

- **The changelog entry is written on the branch, after the pull request exists** — *user's
  decision*, chosen from three options offered. The entry needs a `[#N]` link and `N` does not exist
  until the pull request is opened, so `/ship-it` pushes, opens the pull request, then writes the
  entry. The alternatives (post it as a comment for approval; write it without a link and backfill
  at release time) were both rejected in favor of `[Unreleased]` always being current on `main`.
- **`/publish-it` keeps an interactive changelog reconcile** — *user's decision*, chosen over
  "verify-and-abort" and "full trust". It is a safety net for a branch that merged without
  `/ship-it`, not the normal path, and the file now says so.
- **All four candidate steps from the source implementation were carried over** — *user's decision*:
  rebase, commit review and reword, push and pull request description, and artifact posting.
- **Linear sync and `PLAN.md` history rewriting dropped** — *agent's judgment*, stated to the user
  in the same question and not objected to. Rationale in **Scope**.
- **`mktemp -d` fixes applied here rather than deferred to their own branch** — *agent's judgment*.
  A prior review had deferred them, but this change rewrites the very steps involved and `/ship-it`
  needed the same pattern from scratch; writing the known-flawed version twice made no sense.
  Flagged in the pull request body.
- **Unlisted handoff sections are withheld and named, not published** — *agent's judgment, reversing
  the source implementation*. The original defaults to include, reasoning that an omission would be
  invisible and then deleted with the file. That does not hold here: the handoff is never deleted
  without an explicit confirmation, so withholding costs nothing, and this repository is public so
  publishing an unreviewed section is the irreversible direction.
- **A verification step was added between reword and push** — *agent's judgment after review*.
  `/ship-it` originally rebased onto moved trunk and force-pushed with nothing running the code.
- **`.claude/commands/local-review.md` line 509 was edited** — *agent's judgment*. It said
  `/ship-it` "(Step 7)" handles posting; posting is Step 9 after this branch's renumbering. The file
  stays untracked.

## Insights & Learnings

- **Squash configuration makes commit messages load-bearing.**
  `gh api repos/ExtractableMedia/fastererer` reports `squash_merge_commit_title: COMMIT_OR_PR_TITLE`
  and `squash_merge_commit_message: COMMIT_MESSAGES`. On a **single-commit branch** that commit's
  subject and body become the squash message verbatim and the pull request title is never consulted;
  on a multi-commit branch the title becomes the subject. Confirmed against pull requests #82, #84,
  #88, #89 and #96.
- **`trap … EXIT` cannot work in an agent-executed runbook.** Every Bash tool call is a fresh shell,
  so the trap fires at the end of the command that created the temp directory. This also means
  `$RUN_DIR`, `$NEW_VERSION`, `$BRANCH` and friends do not persist between calls — they are
  placeholders, not variables. Both files now say so.
- **macOS `awk length()` counts bytes regardless of locale.** Even under `LC_ALL=en_US.UTF-8` it
  reports em dashes as 3. Any line-length check on these files must be character-aware (Ruby's
  `String#length` works); a byte check produces ~13 false positives per file.
- **CI does not enforce the 100-character rule.** `.github/linters/.markdown-lint.yml` sets
  `MD013.line_length: 400`, so only `CLAUDE.md` enforces 100. A regression will not be caught.
- **`git grep` cannot see untracked files.** `.claude/commands/local-review.md` is untracked, so a
  rename or renumber sweep using `git grep` reports clean while that file still points at the old
  name. Use `grep -r . --exclude-dir=.git`.
- **`-maxdepth 1` in `/ship-it` Step 9's `find` is load-bearing, not tidiness.**
  `.claude/commands/local-review.md` matches the `local-review*.md` glob at depth 2, so without the
  cap the deletion sub-step would remove the user's own `/local-review` command.
- **`.claude/` never ships in the gem.** The gemspec's `files` predicate keeps only `lib/`, `exe/`,
  `config/` and three root docs — 36 files. These 794 lines cost nothing at install time.
- **`gh api -F` substitutes `{owner}`/`{repo}`/`{branch}` inside values and reads `@file`; `-f` does
  neither.** So `-f body=@file` posts the literal path, and `-F` would rewrite a handoff that quotes
  a `gh api repos/{owner}/{repo}/…` command in its own prose. `jq -Rs '{body: .}'` is the safe form.
- **The repository's changelog entries lead with the reference as a label** — `- [#84]: Description`
  — in all 19 post-fork entries. None uses a trailing `([#84])`.
- **`Refs #N.` and `Closes #N` trailers are in active use** in commit bodies here.

## Constraints & Preferences

- **The `/commit` slash command must be used for every commit message.** Confirmed in both
  `CLAUDE.md` files; `/ship-it` Step 8 was corrected during review to defer to it.
- **The changelog records end-user-facing changes only** — stated explicitly by the user. `/ship-it`
  Step 8 carries a two-list test (what warrants an entry, what does not) derived from that.
- **Both command files must use the full 100-character width without exceeding it** — the user asked
  for both halves, so short prose lines are as wrong as long ones.
- **Do not `git add` untracked scaffolding** — `local-review.md`, `local-review-publish-it.md` and
  `.claude/commands/local-review.md` all stay untracked unless the user says otherwise.

## Dead Ends

- **Byte-based line-length checking.** `awk 'length > 100'` was used first and produced 13
  "violations" per file that do not exist. Switching to `LC_ALL=en_US.UTF-8 awk` did **not** fix it
  — macOS awk ignores the locale for `length()`. This cost a wrong statement to the user that had to
  be corrected. Use Ruby. *This cannot work with macOS awk*, as distinct from not having been
  pursued.
- **Hand-patching line lengths.** Abandoned after the first attempt; a reusable reflow script
  (paragraph-aware, code-fence-preserving, code-span-aware) was written instead and used three
  times. It lives at
  `/private/tmp/claude-501/-Users-matt-code-fastererer2/f7fd6149-7eb3-43b1-b34c-b28daa272d62/scratchpad/reflow.rb`
  — **a session scratchpad, so assume it is gone.** It is ~60 lines and cheap to rewrite: preserve
  fences, headings and tables verbatim; protect `` `code spans` `` and `[links](targets)` from being
  split by replacing their internal spaces with a sentinel before tokenizing.
- **Matching text with exact strings after a reflow.** Repeatedly failed, because the reflow moves
  line breaks. Whitespace-tolerant matching (split the target on `\s+`, join with `\s+`, build a
  regex) was the fix and is worth reaching for first next time.

## Open Questions

- **Non-blocking — should pull request #97 be marked ready for review?** It is a draft. The
  assumption made was to leave it as a draft, matching the pattern from pull request #96 where the
  user merged it themselves. Revisit by asking the user.
- **Non-blocking — should `local-review.md` be posted as a collapsible pull request comment?** The
  user asked for exactly that on the previous branch (#96) but has not asked this time, and
  `/local-review`'s own rules say to post only when explicitly asked. The assumption is to leave it
  unposted. Offering costs one line.
- **Non-blocking — four deferred review findings, all pre-existing in `publish-it.md`.** Recorded as
  F18–F21 in `local-review.md` and reproduced here so they survive that file's deletion:
  - `command -v jq curl ruby` exits 0 under bash even when a tool is missing, so the preflight's
    exit status is not actually a guard (zsh exits 1). An agent reads the output, so it works in
    practice.
  - `git rev-parse --verify "$BRANCH"` matches a *tag* of the same name, so a leftover-branch check
    can fire spuriously. It fails safe — it prompts, never deletes silently.
  - The release-notes footer heredoc is unquoted (it must be, to interpolate URLs) and `$PREV` comes
    from `git describe --tags`. Git ref names permit `$`, `(`, `)` and backtick. Requires tag-push
    access to exploit.
  - The `git stash` ban is stated inside `ship-it.md` but nowhere in `CLAUDE.md` or
    `CONTRIBUTING.md`, so human contributors never see it.

## Next Steps

- [ ] 1. Ask the user whether to mark pull request #97 ready for review (`gh pr ready 97`), and
  whether to post `local-review.md` as a collapsible comment.
- [ ] 2. If posting the review, wrap it in the `<details><summary>` shape the user's `CLAUDE.md`
  requires, sanitize any local-environment detail (this repository is public), and post with
  `gh pr comment 97 --body-file <path>` rather than `--body`.
- [ ] 3. After #97 merges, delete `local-review.md` and `local-review-publish-it.md` if they were
  posted; they are untracked scratch.
- [ ] 4. Optionally open a follow-up branch for the four deferred findings in **Open Questions** —
  they are independent of each other and of this branch.
- [ ] 5. The first real use of `/ship-it` is its own test. Run it on a small branch and note where
  the instructions are ambiguous; nothing in it has been executed end to end.

Item 1 gates items 2 and 3. Item 1 needs the user. Items 4 and 5 are independent.

## Verification

- `gh pr checks 97` — all five pass: `lint`, `rubocop`, `test (3.3)`, `test (3.4)`, `test (4.0)`
  (2026-09-04, against `a5022b8`)
- Character-aware line-length check on both command files — 0 lines over 100 (2026-09-04, after the
  final edit):

  ```bash
  ruby -e 'ARGV.each { |f| n = File.readlines(f, chomp: true).count { |l| l.length > 100 }; puts "#{f}: #{n}" }' \
    .claude/commands/ship-it.md .claude/commands/publish-it.md
  ```

- Split-code-span check on both files — 0 (2026-09-04)
- `/ship-it` Overview item count versus `### Step` heading count — 10 and 10 (2026-09-04)
- **`bin/rspec` and `bin/rubocop` were not run, deliberately.** No Ruby, spec or config file is
  touched on this branch, so `.simplecov`'s coverage totals are byte-identical to `main` and a local
  run would re-measure unchanged code. CI ran the suite on all three Ruby versions anyway; see
  above.
- **Neither `/ship-it` nor `/publish-it` has been executed.** Their shell was verified by reviewers
  running the read-only parts in throwaway repositories, not by running the commands.

## References

- Pull request #97 — https://github.com/ExtractableMedia/fastererer/pull/97 — this branch; draft,
  all checks green, no review yet
- Pull request #96 — https://github.com/ExtractableMedia/fastererer/pull/96 — the immediately prior
  branch, which renamed `/ship-it` to `/publish-it` and whose review comment is worth reading for
  context on why the rename happened
- `445e5c1` — that rename's squashed commit on `main`; proof that a single-commit branch squashes to
  its own message verbatim
- `583c05b` — the split itself on this branch
- `a5022b8` — the review fixes on this branch
- `CHANGELOG.md:16` — an example of the leading `[#N]:` entry format `/ship-it` Step 8 now
  prescribes
- `.github/workflows/release.yml` — declares `environment: rubygems`, which is what makes
  `/publish-it`'s human approval gate real rather than merely documented
- `.github/linters/.markdown-lint.yml` — sets `MD013.line_length: 400`, the reason CI cannot catch a
  100-character regression

## Resume Prompt

```text
Read ship-it-publish-it-split-HANDOFF.md in the project root, then continue from "Next Steps".
Start with item 1 — ask me whether to mark PR #97 ready for review and whether to post
local-review.md as a collapsible PR comment — before doing anything else.
```

## Handoff History

- **2026-09-04** — Initial handoff: `/publish-it` split into `/ship-it` (branch preparation) and
  `/publish-it` (release only). Two commits pushed, PR #97 open as a draft with all CI green,
  `/local-review` returned 27 findings of which 18 are fixed and 4 deferred. Nothing in progress;
  the open decision is whether to mark the draft ready. Captured by Opus 5 (`claude-opus-5[1m]`)
