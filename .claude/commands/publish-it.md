# Publish It

Cut the next `fastererer` release: bump the version, promote `[Unreleased]` into a dated section,
merge that through a pull request, tag the merged commit, publish the gem to RubyGems and create the
matching GitHub Release.

This command publishes. It does not prepare branches for merge — `/ship-it` does that, and it is
what records each change in `[Unreleased]` as the work lands. By the time `/publish-it` runs, the
changelog should already be complete; Step 1 is a safety net for anything that merged without it.

Run it from `main`, with the work you intend to release already merged.

## Overview

1. Reconcile the changelog against pull requests merged since the last tag
1. Determine the new version number, defaulting from the now-complete `[Unreleased]` section
1. Bump `lib/fastererer/version.rb` and `Gemfile.lock`, and promote `[Unreleased]` into a new dated
   section per [Keep a Changelog 1.1.0]
1. Commit, push, open a pull request, watch CI, and merge with "Rebase and merge"
1. Sync local `main` with `origin/main`
1. Tag the merged commit, push it, and watch the gated release workflow publish the gem to RubyGems
   once a human approves the deployment
1. Create the GitHub Release from the new changelog section and confirm the posted body carries the
   expected changelog sections

[Keep a Changelog 1.1.0]: https://keepachangelog.com/en/1.1.0/

## Scratch directory

Several steps write temporary files. Create one run directory up front and reuse it, rather than
scattering fixed names through `/tmp`:

```bash
RUN_DIR=$(mktemp -d "${TMPDIR:-/tmp}/publish-it.XXXXXXXX"); echo "$RUN_DIR"
```

`mktemp -d` creates the directory mode 0700 with an unpredictable suffix, so nothing can pre-plant a
symlink at a path this run is about to redirect into, and no leftover file from an earlier run can
be read back and published as this run's release notes. Both are possible with a fixed
`/tmp/release-notes.md`, and the second is the likelier accident: Step 7 appends its footer with
`>>`, so a re-run after a partial failure would otherwise append a second footer to the first run's
file.

**Record the printed path and write it literally into every later command.** Do not wrap this in a
`trap … EXIT` cleanup: each Bash call runs in its own shell, so the trap fires at the end of the
very command that created the directory. Remove the directory in Step 7, after the release body has
been verified.

## Process

### Preflight checks

Before starting Step 1, verify the environment is in a known state. Every path below is relative to
the repository root, so run from there:

1. **Confirm the tooling is present and `gh` is authenticated:**

   ```bash
   gh auth status
   command -v jq curl ruby
   ```

   `gh` needs permission to merge pull requests and create releases. Only one later step needs the
   `jq` binary — the `curl` in Step 6 that checks RubyGems; the `gh --json … --jq` calls elsewhere
   use gh's own embedded engine and would work without it. A missing tool should abort here rather
   than mid-release.

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

### Step 1: Reconcile the changelog against merged pull requests

`/ship-it` should already have recorded each merged change, so this step normally finds nothing to
add. It runs first regardless, because Step 2's suggested bump reads `[Unreleased]` and is only
trustworthy against a complete section.

1. **List pull requests merged into `main` since the last version tag:**

   ```bash
   LAST_TAG=$(git describe --tags --abbrev=0)
   LAST_TAG_DATE=$(git log -1 --format=%aI "$LAST_TAG" | cut -c1-10)
   gh pr list --base main --state merged --search "merged:>=$LAST_TAG_DATE" \
     --limit 100 --json number,title,mergedAt
   ```

   The `cut` truncates the tag's commit timestamp to `YYYY-MM-DD`, which is the format GitHub's
   search API matches reliably (full ISO 8601 timestamps can produce edge-case misses for pull
   requests merged in the same minute).

1. **Add an entry for every merged pull request that isn't represented.** Compare the list against
   the `[Unreleased]` section, and for each pull request with no entry ask the user via
   `AskUserQuestion` whether to add it and under which Keep a Changelog section.

   Write the entry exactly as `/ship-it` Step 8 describes — the leading `[#N]:` label, the matching
   link definition in the block at the bottom, ascending by number. That step is the primary path
   and this one is the exception, so keep the format defined in one place rather than restating it
   here and letting the two drift.

1. **If nothing needed adding, continue to Step 2.** That is the expected outcome when `/ship-it`
   has been run on each branch, and it is not a reason to stop — the release itself is still ahead.
   Say which of the two reasons applies: every merged pull request already has an entry, or nothing
   that merged warranted one. A window of only tooling, CI, dependency and documentation work
   reaches this point with `[Unreleased]` still empty, and reporting that as "already recorded"
   would be false. An empty `[Unreleased]` aborts in Step 2.

### Step 2: Determine the new version

1. **Read the current version** from `lib/fastererer/version.rb`:

   ```bash
   CURRENT=$(ruby -e "require_relative 'lib/fastererer/version'; puts Fastererer::VERSION")
   ```

1. **Inspect the reconciled `[Unreleased]` section** of `CHANGELOG.md` to suggest the appropriate
   bump. The gem is past 1.0.0 and the changelog claims Semantic Versioning, so a breaking change is
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

1. **Validate the answer before it reaches a shell command,** while it is still a string returned by
   `AskUserQuestion`:

   - Must match `^\d+\.\d+\.\d+$`
   - Must be greater than the current version

   Validating first is the point — the assignment below is where a malformed value would first be
   interpreted, so a check placed after it guards every later use except the one that introduces it.

1. **Capture the confirmed version into `NEW_VERSION`.** Like `RUN_DIR`, this is a placeholder
   rather than a live variable: each Bash call runs in its own shell, so it does not survive to the
   next command. Record the value and write it literally into every later block — the same applies
   to `BRANCH`, `TITLE`, `SHA` and `RUN_ID`.

   ```bash
   NEW_VERSION="X.Y.Z"   # replace with the version returned by AskUserQuestion
   ```

1. **Confirm the matching `vX.Y.Z` tag does not already exist,** locally or on origin:

   ```bash
   git tag --list "v$NEW_VERSION" | grep . && echo "tag exists locally"
   git ls-remote --tags origin "refs/tags/v$NEW_VERSION" | grep . && echo "tag exists on origin"
   ```

   If the tag exists on origin, abort — that version is already released. If it exists locally but
   not on origin, it is most likely a leftover from an aborted run: confirm with the user, then
   `git tag -d "v$NEW_VERSION"` and continue.

### Step 3: Bump the version and promote the changelog

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

### Step 4: Commit, push, open pull request, watch CI, merge

1. **Set the branch and title:**

   ```bash
   BRANCH="release-v$NEW_VERSION"; TITLE="Prepare v$NEW_VERSION release"
   ```

1. **Sync `main` and create the branch from it.** The Preflight step confirmed `main` is checked
   out, but `git pull` here guarantees the branch is fast-forwarded to `origin/main` before
   branching off:

   ```bash
   git pull --ff-only origin main
   ```

   Check for a pre-existing `$BRANCH` — local or remote — left over from a prior aborted run. The
   branch name carries the version, so a leftover means a previous attempt at this same release did
   not finish:

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

1. **Commit using `/commit`,** with `$TITLE` as the suggested subject. The body should summarize the
   change types being released — the counts under each Keep a Changelog section heading.

1. **Push and open a pull request:**

   ```bash
   git push -u origin "$BRANCH"
   gh pr create --assignee @me --title "$TITLE" --body-file "$RUN_DIR/pr-body.md"
   ```

   Build `$RUN_DIR/pr-body.md` with a `## Summary` section, a `## Test plan` section, and a
   `## Release notes preview` section that pastes the new changelog section.

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

   Use `AskUserQuestion` to confirm. This is the point of no return for the version bump. Then:

   ```bash
   gh pr merge --rebase --delete-branch
   ```

### Step 5: Sync local main with origin

```bash
git checkout main
git pull --ff-only origin main
```

If `--ff-only` fails (local `main` diverged), surface the conflict and pause. Do not attempt to
reset; the user may have intentional local state.

### Step 6: Tag the release commit and publish

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
   ' "$NEW_VERSION" CHANGELOG.md > "$RUN_DIR/release-notes.md"
   [ -s "$RUN_DIR/release-notes.md" ] || echo "No [$NEW_VERSION] section found in CHANGELOG.md"
   ```

   This deliberately uses no dollar-digit token. A slash command's arguments are interpolated into
   this file before it runs, and every dollar-digit placeholder is replaced — which silently broke
   the `awk` version of this script, since awk names the current record with exactly that form.
   Matching with `start_with?` on a plain string also means there is no regex at all, so the dots in
   `0.13.0` cannot act as wildcards and need no escaping.

   The extraction exits 0 whether or not it matched, so the emptiness check is what catches a
   heading that doesn't take the `## [X.Y.Z] - YYYY-MM-DD` form Step 3 wrote — abort and fix the
   heading rather than publishing a release whose body is nothing but the footer.

1. **Convert `[#N]` reference-style pull request refs to bare `#N`** so they render without bracket
   cruft in the release body (GitHub's autolinker handles `#N` in repo-context release pages):

   ```bash
   ruby -i -pe 'gsub(/\[#(\d+)\]/, "#\\1")' "$RUN_DIR/release-notes.md"
   ```

   `ruby -i` edits in place identically on macOS and Linux, unlike `sed -i`, which needs different
   argument syntax on each. The backreference is written `\1` with a backslash rather than in the
   dollar-digit form, for the same reason the block above avoids awk's record variable: those tokens
   are slash-command argument placeholders, replaced before the line ever runs.

1. **Append a footer** with the compare link and the RubyGems page. URLs are assigned to variables
   first so the heredoc lines stay readable:

   ```bash
   PREV=$(git describe --tags --abbrev=0 "v$NEW_VERSION^")  # nearest tag before the release
   COMPARE_URL="https://github.com/ExtractableMedia/fastererer/compare/$PREV...v$NEW_VERSION"
   GEM_URL="https://rubygems.org/gems/fastererer/versions/$NEW_VERSION"
   cat >> "$RUN_DIR/release-notes.md" <<EOF

   ---

   **Full changelog:** [${PREV}...v$NEW_VERSION]($COMPARE_URL)
   **Gem:** [fastererer $NEW_VERSION on rubygems.org]($GEM_URL)
   EOF
   ```

   Deriving `PREV` from ancestry matches how Step 1 finds the last tag, and agrees with the compare
   link Step 3 wrote into the changelog. Sorting all tags by version instead would pick the wrong
   one whenever a tag sorts above the release being cut — a pre-release, or a leftover from an
   aborted run.

1. **Create the Release:**

   ```bash
   gh release create "v$NEW_VERSION" \
     --title "v$NEW_VERSION" \
     --notes-file "$RUN_DIR/release-notes.md" \
     --latest
   ```

1. **Verify the release saved successfully** and the body carries the expected Keep a Changelog
   section headings:

   ```bash
   BODY="$RUN_DIR/release-body.md"
   gh release view "v$NEW_VERSION" --json body --jq '.body' > "$BODY"
   if grep -q "^### \(Added\|Changed\|Deprecated\|Removed\|Fixed\|Security\)" "$BODY"
   then
     echo "Release body contains Keep a Changelog sections"
   else
     echo "Release body is missing its changelog sections — inspect before announcing"
   fi
   ```

   Writing the body to a file first keeps a `gh` auth or network failure distinguishable from a
   missing section; piping straight into `grep` makes the two look identical. A byte-exact diff
   against the file we posted is fragile because GitHub normalizes trailing whitespace and newlines,
   so this structural check stands in for it — note that it confirms the sections are present, not
   that they came from the right version. If it fails, do not report success: correct the body with
   `gh release edit "v$NEW_VERSION" --notes-file "$RUN_DIR/release-notes.md"`.

1. **Report the release URL** to the user as the final confirmation:

   ```bash
   gh release view "v$NEW_VERSION" --json url --jq '.url'
   ```

1. **Remove the scratch directory** once the release body has been verified:

   ```bash
   rm -rf -- "$RUN_DIR"
   ```

   Leave it in place if the verification above failed — it holds the release notes as they were
   assembled, which is what `gh release edit` needs to correct the posted body.

## Interactive confirmations

Use `AskUserQuestion` to confirm key decision points:

- **Step 1** — Confirm each changelog addition for a merged pull request that has no entry, and the
  Keep a Changelog section it belongs under
- **Step 2** — Confirm the version number, offering the suggested default as the first option
- **Step 3** — Confirm the `version.rb` + `CHANGELOG.md` + `Gemfile.lock` diff before it is
  committed in Step 4
- **Step 4** — Confirm whether to delete a leftover branch from an aborted run, and confirm before
  merging the pull request; that merge is the point of no return for the version bump
- **Step 6** — Confirm before creating and pushing the tag. The push starts the gated release
  workflow, and once a human approves the deployment the published gem can be yanked but not deleted

## Important notes

- **Never** create a release commit directly on `main` — always go through a pull request
- **Never** force-push `main` or replace an existing tag with a new target
- **Never** approve the `rubygems` environment gate on the user's behalf — surface the run URL and
  let them approve it
- **Never** leave `main` carrying a bumped-but-untagged version. The bump commit merges and the tag
  goes out in the same run, which is what lets Step 6 require `HEAD` to be the release commit
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
- If `[Unreleased]` is empty after reconciliation, Step 2 aborts: nothing has merged since the last
  tag that a user of the gem would notice, so there is no release to cut
- **Recording changes is `/ship-it`'s job.** Step 1 exists to catch what merged without it, not as
  the normal route — a reconcile that keeps finding gaps means branches are skipping `/ship-it`

## Example workflow

```text
$ /publish-it

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
✅ Release body contains the expected changelog sections

🎉 Published v1.1.0!
```
