# Ship It

Move `fastererer` toward its next release: reconcile the CHANGELOG against what has merged, and —
when you're ready — bump the version, promote `[Unreleased]` into a dated section, tag the merged
commit, publish the gem to RubyGems and create the matching GitHub Release.

## Arguments

`$ARGUMENTS` selects the mode. The two halves exist so that merging work doesn't have to mean
releasing it:

- **`prepare`** — reconcile the CHANGELOG's `[Unreleased]` section against PRs merged since the last
  tag and push any additions through a PR, then stop. No version bump, no tag, no publish. Run it as
  often as you like between releases and `[Unreleased]` accumulates.
- **`publish`** — reconcile as above, then cut the release: bump the version and `Gemfile.lock`,
  promote `[Unreleased]`, merge that through a PR, tag it, and publish.
- **no argument** — the same as `publish`. Reconciliation and the bump ride in a single PR.

The version bump lives entirely in the publish half, so `main` never carries a bumped-but-unreleased
version. The bump commit merges and the tag goes out in the same run, which is what lets Step 6 keep
requiring `HEAD` to be the release commit.

Each step states the modes it runs in. Skip a step entirely when the current mode isn't listed — do
not run it "harmlessly".

## Overview

1. Reconcile the CHANGELOG against PRs merged since the last tag *(all modes)*
1. Determine the new version number, defaulting from the now-complete `[Unreleased]` section
   *(publish)*
1. Bump `lib/fastererer/version.rb` and `Gemfile.lock`, and promote `[Unreleased]` into a new dated
   section per [Keep a Changelog 1.1.0] *(publish)*
1. Commit, push, open a PR, watch CI, and merge with "Rebase and merge" *(all modes — `prepare`
   stops here)*
1. Sync local `main` with `origin/main` *(publish)*
1. Tag the merged commit, push it, and watch the gated release workflow publish the gem to RubyGems
   once a human approves the deployment *(publish)*
1. Create the GitHub Release from the new CHANGELOG section and confirm the posted body carries the
   expected CHANGELOG sections *(publish)*

[Keep a Changelog 1.1.0]: https://keepachangelog.com/en/1.1.0/

## Process

### Preflight checks

*Runs in: all modes.*

Before starting Step 1, verify the environment is in a known state. Every path below is relative to
the repository root, so run from there:

1. **Confirm the tooling is present and `gh` is authenticated:**

   ```bash
   gh auth status
   command -v jq curl perl ruby
   ```

   `gh` needs permission to merge pull requests and create releases, and `jq` is load-bearing in
   three later steps. A missing tool should abort here rather than mid-release.

1. **Confirm `main` is the current branch:**

   ```bash
   git branch --show-current
   ```

   If the output is not `main`, abort and surface — do not auto-switch. The user may have
   intentional in-progress work on another branch.

1. **Confirm the working tree has no tracked modifications:**

   ```bash
   git diff --quiet && git diff --cached --quiet
   ```

   If either returns non-zero (unstaged or staged changes to tracked files), abort and surface — do
   not auto-stash or discard. Untracked files are tolerated.

1. **Fetch the latest refs and tags from origin** so subsequent comparisons are accurate:

   ```bash
   git fetch --tags origin
   ```

### Step 1: Reconcile the CHANGELOG against merged PRs

*Runs in: all modes.* Reconciling before anything else is what makes Step 2's suggested bump
trustworthy — the heuristic reads `[Unreleased]`, so it has to run against a complete section.

1. **List PRs merged into `main` since the last version tag:**

   ```bash
   LAST_TAG=$(git describe --tags --abbrev=0)
   LAST_TAG_DATE=$(git log -1 --format=%aI "$LAST_TAG" | cut -c1-10)
   gh pr list --base main --state merged --search "merged:>=$LAST_TAG_DATE" \
     --limit 100 --json number,title,mergedAt
   ```

   The `cut` truncates the tag's commit timestamp to `YYYY-MM-DD`, which is the format GitHub's
   search API matches reliably (full ISO 8601 timestamps can produce edge-case misses for PRs merged
   in the same minute).

1. **Add an entry for every merged PR that isn't represented.** Compare the list against the
   `[Unreleased]` section, and for each PR with no entry ask the user via `AskUserQuestion` whether
   to add it and under which Keep a Changelog section.

   Entries use reference-style links, so each new `[#N]` needs a matching
   `[#N]: https://github.com/ExtractableMedia/fastererer/pull/N` def in the block at the bottom of
   the file, keeping its ascending-by-number order — use `/issues/N` where the reference is an issue
   rather than a PR. Without the def the entry renders literally as `[#N]` on GitHub.

1. **If nothing needed adding, decide whether there is anything left to do:**

   - In `prepare` mode, stop here and report that the CHANGELOG already records every merged PR.
     There is no commit to make, so do not create a branch or open a PR
   - In `publish` mode, continue to Step 2 — the release itself is still ahead

### Step 2: Determine the new version

*Runs in: `publish`. Skip entirely in `prepare`.*

1. **Read the current version** from `lib/fastererer/version.rb`:

   ```bash
   CURRENT=$(ruby -e "require_relative 'lib/fastererer/version'; puts Fastererer::VERSION")
   ```

1. **Inspect the reconciled `[Unreleased]` section** of `CHANGELOG.md` to suggest the appropriate
   bump. The gem is past 1.0.0 and the CHANGELOG claims Semantic Versioning, so a breaking change is
   a major bump rather than a minor one:

   - `### Removed` entries, or a `### Changed` entry describing a breaking change → suggest a
     **major** bump (e.g., `1.0.0 → 2.0.0`)
   - `### Added`, non-breaking `### Changed`, or `### Deprecated` entries → suggest a **minor** bump
     (e.g., `1.0.0 → 1.1.0`)
   - Only `### Fixed` or `### Security` entries → suggest a **patch** bump (e.g., `1.0.0 → 1.0.1`)
   - Empty `[Unreleased]` → abort: nothing has merged since the last tag, so there is no release to
     cut

1. **Confirm the version** with the user via `AskUserQuestion`, presenting the suggested default and
   letting them override (e.g., to skip ahead, or to reclassify a change the heuristic misread).

1. **Capture the confirmed version into `NEW_VERSION`** for use in all later steps. Every subsequent
   code block assumes this variable is set:

   ```bash
   NEW_VERSION="X.Y.Z"   # replace with the version returned by AskUserQuestion
   ```

1. **Validate the chosen version:**

   - Must match `^\d+\.\d+\.\d+$`
   - Must be greater than the current version
   - The matching `vX.Y.Z` tag must not already exist locally or on origin:

     ```bash
     git tag --list "v$NEW_VERSION" | grep . && echo "tag exists locally"
     git ls-remote --tags origin "refs/tags/v$NEW_VERSION" | grep . && echo "tag exists on origin"
     ```

   If the tag exists on origin, abort — that version is already released. If it exists locally but
   not on origin, it is most likely a leftover from an aborted run: confirm with the user, then
   `git tag -d "v$NEW_VERSION"` and continue.

### Step 3: Bump the version and promote the CHANGELOG

*Runs in: `publish`. Skip entirely in `prepare`.*

1. **Bump `lib/fastererer/version.rb`** by editing the `VERSION` constant from the current value to
   the new one, then refresh the lockfile:

   ```bash
   bundle install                # rewrites the fastererer (X.Y.Z) pins in Gemfile.lock
   git diff --stat Gemfile.lock  # expect only those pins to change
   ```

   The `Gemfile` uses `gemspec`, so the gem is its own path dependency. CI runs bundler frozen, and
   a stale lockfile fails every job at "Set up Ruby" with exit code 16 before any test runs.

1. **Promote `[Unreleased]` in `CHANGELOG.md`:**

   - Rename the `## [Unreleased]` heading to `## [X.Y.Z] - YYYY-MM-DD` using today's date
     (`date +%Y-%m-%d`)
   - Insert a fresh empty `## [Unreleased]` heading directly above the new dated section so future
     changes have a place to land

1. **Update the version links at the bottom of the file:**

   - Repoint the existing `[Unreleased]` def to compare from the new version to `HEAD`
     (`compare/vX.Y.Z...HEAD`)
   - Add a new `[X.Y.Z]: .../compare/vPREV...vX.Y.Z` def directly below `[Unreleased]`, preserving
     the descending order of older versions

### Step 4: Commit, push, open PR, watch CI, merge

*Runs in: all modes.* The branch name, commit subject and PR body differ by mode; everything else is
identical.

1. **Set the branch and title for the mode:**

   ```bash
   # publish, and the no-argument run
   BRANCH="release-v$NEW_VERSION"; TITLE="Prepare v$NEW_VERSION release"
   # prepare
   BRANCH="changelog-catch-up";    TITLE="Record merged PRs in the CHANGELOG"
   ```

1. **Sync `main` and create the branch from it.** The Preflight step confirmed `main` is checked
   out, but `git pull` here guarantees the branch is fast-forwarded to `origin/main` before
   branching off:

   ```bash
   git pull --ff-only origin main
   ```

   Check for a pre-existing `$BRANCH` — local or remote — left over from a prior aborted run.
   `changelog-catch-up` is reused by every `prepare` run, so in that mode a leftover is the likely
   case rather than the exceptional one:

   ```bash
   git rev-parse --verify "$BRANCH" 2>/dev/null
   git ls-remote --heads origin "$BRANCH" | grep .
   ```

   If either exists, ask the user via `AskUserQuestion` whether to delete it (and then
   `git branch -D` / `git push origin --delete`) or to abort so they can inspect it. Do not delete
   without confirmation.

   Once clean, create the branch:

   ```bash
   git checkout -b "$BRANCH"
   ```

1. **Commit using `/commit`,** with `$TITLE` as the suggested subject. In `publish` mode the body
   should summarize the change types being released (counts under each Keep a Changelog section
   header); in `prepare` mode it should say which merged PRs are now recorded.

1. **Push and open a PR:**

   ```bash
   git push -u origin "$BRANCH"
   gh pr create --assignee @me --title "$TITLE" --body-file /tmp/ship-it-pr-body.md
   ```

   Build `/tmp/ship-it-pr-body.md` with a `## Summary` section and a `## Test plan` section. In
   `publish` mode, add a `## Release notes preview` section that pastes the new CHANGELOG section.

1. **Watch CI checks:**

   ```bash
   gh pr checks --watch --fail-fast
   ```

   Run straight after `gh pr create`, this can exit with an error saying no checks have been
   reported on the branch — that means the workflows have not registered yet, not that CI failed.
   Wait a few seconds and re-run. Only a *reported* failure is a failure: surface it and pause for
   the user to decide whether to abort or fix. `--fail-fast` stops the watch at the first failing
   check instead of waiting out the rest of the matrix.

1. **Merge using "Rebase and merge":**

   Use `AskUserQuestion` to confirm. In `publish` mode this is the point of no return for the
   version bump. Then:

   ```bash
   gh pr merge --rebase --delete-branch
   ```

1. **In `prepare` mode, stop here.** Report which PRs are now recorded in `[Unreleased]`, and that
   nothing was released — the version is unchanged and no tag was created. Say that
   `/ship-it publish` cuts the release when the user is ready.

### Step 5: Sync local main with origin

*Runs in: `publish`.*

```bash
git checkout main
git pull --ff-only origin main
```

If `--ff-only` fails (local `main` diverged), surface the conflict and pause. Do not attempt to
reset; the user may have intentional local state.

### Step 6: Tag the release commit and publish

*Runs in: `publish`.*

1. **Confirm `HEAD` is the merged release commit:**

   ```bash
   git log -1 --oneline
   ```

   The subject line should be `Prepare v$NEW_VERSION release` (or whatever was used in Step 4). If
   it doesn't match, abort and surface the discrepancy — something has gone wrong between merge and
   sync. Do not proceed to tag creation on an unverified commit.

1. **Confirm with the user via `AskUserQuestion` before tagging.** This is the irreversible step —
   pushing the tag starts the release workflow that publishes the gem, and a published gem version
   can be yanked but not deleted. Confirm before the tag exists, not after: a tag created and then
   declined lingers locally and aborts Step 2 of the next run.

1. **Create an annotated tag and push it** — the push triggers `.github/workflows/release.yml`:

   ```bash
   git tag -a "v$NEW_VERSION" -m "v$NEW_VERSION"
   git push origin "v$NEW_VERSION"
   ```

   Annotated tags are the convention here — every tag but the lightweight `v0.12.0` follows it, and
   `git cat-file -t vX.Y.Z` reports `tag` for an annotated tag and `commit` for a lightweight one.
   If the push fails, delete the local tag with `git tag -d "v$NEW_VERSION"` before retrying.

1. **Find the release run and hand its URL to the user.** Identify the run by the commit being
   released rather than by recency, so a previous release's completed run can't be mistaken for this
   one:

   ```bash
   SHA=$(git rev-parse HEAD)
   RUN_ID=$(gh run list --workflow=release.yml --commit "$SHA" --limit=1 \
     --json databaseId --jq '.[0].databaseId')
   gh run view "$RUN_ID" --json url --jq '.url'
   ```

   An empty `RUN_ID` means GitHub has not registered the run yet — retry a few times, and report a
   workflow that never appears rather than waiting on it indefinitely.

1. **Wait for the user to approve the `rubygems` deployment.** The release job declares
   `environment: rubygems`, so the run sits at "Waiting" until a human approves it in the run's
   **Review deployments** prompt. Give the user the URL from the previous sub-step and wait — never
   approve this gate on their behalf. The human review before the irreversible push to RubyGems is
   the entire point of the gate.

1. **Watch the release workflow** to completion:

   ```bash
   gh run watch "$RUN_ID" --exit-status
   ```

   `--exit-status` makes a failed publish exit non-zero; without it `gh run watch` reports the same
   success whether the run passed or failed.

1. **Verify the gem is live on RubyGems:**

   ```bash
   curl -fsSL "https://rubygems.org/api/v1/versions/fastererer.json" \
     | jq -r '.[0].number'
   ```

   Output should be `$NEW_VERSION`. If not, stop and surface the discrepancy.

### Step 7: Create the GitHub Release

*Runs in: `publish`.*

1. **Extract the new version's section** from `CHANGELOG.md` into release notes. The script reads
   everything between the new version heading and the next `##` heading:

   ```bash
   ruby -e '
     ver, path = ARGV
     found = false
     File.foreach(path) do |line|
       if line.start_with?("## [#{ver}]") then found = true; next end
       break if found && line.start_with?("## ")
       print line if found
     end
   ' "$NEW_VERSION" CHANGELOG.md > /tmp/release-notes.md
   [ -s /tmp/release-notes.md ] || echo "No [$NEW_VERSION] section found in CHANGELOG.md"
   ```

   This deliberately uses no dollar-digit token. A slash command's arguments are interpolated
   into this file before it runs, and every dollar-digit placeholder is replaced — which silently
   broke the `awk` version of this script, since awk names the current record with exactly that
   form. Matching with `start_with?` on a plain string also means there is no regex at all, so
   the dots in `0.13.0` cannot act as wildcards and need no escaping.

   The extraction exits 0 whether or not it matched, so the emptiness check is what catches a
   heading that doesn't take the `## [X.Y.Z] - YYYY-MM-DD` form Step 3 wrote — abort and fix the
   heading rather than publishing a release whose body is nothing but the footer.

1. **Convert `[#N]` reference-style PR refs to bare `#N`** so they render without bracket cruft in
   the release body (GitHub's autolinker handles `#N` in repo-context release pages):

   ```bash
   ruby -i -pe 'gsub(/\[#(\d+)\]/, "#\\1")' /tmp/release-notes.md
   ```

   `ruby -i` edits in place identically on macOS and Linux, unlike `sed -i`, which needs different
   argument syntax on each. The backreference is written `\1` with a backslash rather than in the
   dollar-digit form, for the same reason the block above avoids awk's record variable: those
   tokens are slash-command argument placeholders, replaced before the line ever runs.

1. **Append a footer** with the compare link and the RubyGems page. URLs are assigned to variables
   first so the heredoc lines stay readable:

   ```bash
   PREV=$(git describe --tags --abbrev=0 "v$NEW_VERSION^")  # nearest tag before the release
   COMPARE_URL="https://github.com/ExtractableMedia/fastererer/compare/$PREV...v$NEW_VERSION"
   GEM_URL="https://rubygems.org/gems/fastererer/versions/$NEW_VERSION"
   cat >> /tmp/release-notes.md <<EOF

   ---

   **Full changelog:** [${PREV}...v$NEW_VERSION]($COMPARE_URL)
   **Gem:** [fastererer $NEW_VERSION on rubygems.org]($GEM_URL)
   EOF
   ```

   Deriving `PREV` from ancestry matches how Step 1 finds the last tag, and agrees with the compare
   link Step 3 wrote into the CHANGELOG. Sorting all tags by version instead would pick the wrong
   one whenever a tag sorts above the release being cut — a pre-release, or a leftover from an
   aborted run.

1. **Create the Release:**

   ```bash
   gh release create "v$NEW_VERSION" \
     --title "v$NEW_VERSION" \
     --notes-file /tmp/release-notes.md \
     --latest
   ```

1. **Verify the release saved successfully** and the body carries the expected Keep a Changelog
   section headings:

   ```bash
   gh release view "v$NEW_VERSION" --json body --jq '.body' > /tmp/release-body.md
   if grep -q "^### \(Added\|Changed\|Deprecated\|Removed\|Fixed\|Security\)" /tmp/release-body.md
   then
     echo "Release body contains Keep a Changelog sections"
   else
     echo "Release body is missing its CHANGELOG sections — inspect before announcing"
   fi
   ```

   Writing the body to a file first keeps a `gh` auth or network failure distinguishable from a
   missing section; piping straight into `grep` makes the two look identical. A byte-exact diff
   against the file we posted is fragile because GitHub normalizes trailing whitespace and newlines,
   so this structural check stands in for it — note that it confirms the sections are present, not
   that they came from the right version. If it fails, do not report success: correct the body with
   `gh release edit "v$NEW_VERSION" --notes-file /tmp/release-notes.md`.

1. **Report the release URL** to the user as the final confirmation:

   ```bash
   gh release view "v$NEW_VERSION" --json url --jq '.url'
   ```

## Interactive Confirmations

Use `AskUserQuestion` to confirm key decision points:

- **Step 1** *(all modes)* — Confirm each CHANGELOG addition for a merged PR that has no entry, and
  the Keep a Changelog section it belongs under
- **Step 2** *(publish)* — Confirm the version number (suggested default as first option)
- **Step 3** *(publish)* — Confirm the `version.rb` + `CHANGELOG.md` + `Gemfile.lock` diff before it
  is committed in Step 4
- **Step 4** *(all modes)* — Confirm whether to delete a leftover branch from an aborted run, and
  confirm before merging the PR. In `publish` mode that merge is the point of no return for the
  version bump
- **Step 6** *(publish)* — Confirm before creating and pushing the tag (the push starts the gated
  release workflow; once a human approves the deployment, the published gem can be yanked but not
  deleted)

## Important Notes

- **Never** create a release commit directly on `main` — always go through a PR
- **Never** force-push `main` or replace an existing tag with a new target
- **Never** approve the `rubygems` environment gate on the user's behalf — surface the run URL and
  let them approve it
- **Never** bump the version in `prepare` mode. The bump and the tag belong to the same run; a
  bumped-but-untagged `main` is the state this split exists to avoid
- **Always** update `Gemfile.lock` alongside `lib/fastererer/version.rb` in the same commit; the
  `Gemfile` uses `gemspec`, so a stale lockfile fails every CI job at "Set up Ruby" with exit code
  16 before any test runs
- **Always** use annotated tags (`git tag -a`) — that is the convention here, and every tag but the
  lightweight `v0.12.0` follows it; `git cat-file -t vX.Y.Z` reports `tag` for an annotated tag and
  `commit` for a lightweight one
- A gem version pushed to RubyGems can be **yanked** but not deleted — double-check the version
  before Step 6
- If the release workflow fails after the gem publishes (e.g., the `rubygems/release-gem` action
  times out waiting for the version to propagate), the gem is still published — re-run the failed
  step or proceed to Step 7 manually
- If `[Unreleased]` is empty after reconciliation, `publish` aborts early: there's nothing to ship

## Example Workflows

A `prepare` run, recording work that has merged without touching the version:

```text
$ /ship-it prepare

Preflight: gh authenticated, on main, working tree clean, refs fetched

Checking PRs merged since v1.0.0...
  #88 Add a scanner for Array#count with no block   → not in [Unreleased]
  #89 Fix false positive on safe-navigation chains  → not in [Unreleased]
Add #88 under Added and #89 under Fixed? [Y/n]

Adding entries and their [#N] link definitions
Creating branch changelog-catch-up
Committing "Record merged PRs in the CHANGELOG"
Opening PR #90... ✅ All checks passed
Merging PR #90 with rebase-and-merge? [Y/n]
✅ Merged

[Unreleased] now records #88 and #89. Version unchanged at 1.0.0, nothing tagged.
Run `/ship-it publish` to cut the release.
```

A `publish` run some days later, once `[Unreleased]` has enough in it:

```text
$ /ship-it publish

Preflight: gh authenticated, on main, working tree clean, refs fetched

Checking PRs merged since v1.0.0...
All merged PRs are represented in [Unreleased].

Reading lib/fastererer/version.rb → current 1.0.0
Reading CHANGELOG.md [Unreleased] → 2 Added, 1 Fixed
Suggested bump: 1.1.0 (minor) — override? [1.1.0]

Bumping version.rb: 1.0.0 → 1.1.0
Running bundle install → Gemfile.lock pins updated
Promoting [Unreleased] → ## [1.1.0] - YYYY-MM-DD
Updating compare links

Diff preview:
[shows version.rb, CHANGELOG.md and Gemfile.lock diff]
Proceed? [Y/n]

Creating branch release-v1.1.0
Committing "Prepare v1.1.0 release"
Opening PR #91...
Waiting for CI checks via `gh pr checks --watch --fail-fast`...
✅ All checks passed

Merging PR #91 with rebase-and-merge? [Y/n]
✅ Merged

git checkout main && git pull --ff-only origin main
At commit abc1234 (HEAD)

Tag v1.1.0? This starts the gated release workflow. [Y/n]
Tagged and pushed v1.1.0

Release run queued: https://github.com/ExtractableMedia/fastererer/actions/runs/26000000
⏸️  Waiting for you to approve the `rubygems` deployment...
✅ Approved

Watching release workflow run #26000000...
✅ Workflow succeeded
✅ Gem fastererer 1.1.0 published to RubyGems

Extracting release notes from CHANGELOG.md
Creating GitHub Release v1.1.0...
✅ Release created: https://github.com/ExtractableMedia/fastererer/releases/tag/v1.1.0
✅ Release body contains the expected CHANGELOG sections

🎉 Shipped v1.1.0!
```
