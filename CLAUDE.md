# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this
repository.

## Public Repository

This repository is public — its code, issues, pull requests and commit history are all visible to
anyone. Don't name private repositories, internal systems, internal ticket IDs or internal hostnames
in anything published here: PR and issue text, commit messages, code comments and tracked files
alike. When a convention or technique comes from private work, describe it on its own terms — the
provenance adds nothing a reader here can use. Note that editing a pull request description does not
erase the original; GitHub keeps it in the description's edit history.

## Test Commands

- Run the suite: `bin/rspec` — always the binstub, never `bundle exec rspec`
- Run a specific test file: `bin/rspec path/to/spec_file.rb`
- Run a specific example: `bin/rspec path/to/spec_file.rb:line_number`
- **A narrowed run proves nothing about coverage.** `.simplecov` applies its 100% line and branch
  floors only when the invocation names no path and no `-e`, `--example`, `-t` or `--tag`; anything
  narrower reports coverage without failing on it. The suite is small — run it whole before
  claiming coverage holds.
- See `spec/CLAUDE.md` for conventions on writing and structuring specs

## Lint Commands

- Run RuboCop with auto-correct after modifying any Ruby file: `bin/rubocop -A`
- `rake` with no arguments runs `spec` then `rubocop`
- **Fix new RuboCop offenses in the code.** Never reach for `bin/rubocop --auto-gen-config` — this
  repo deliberately carries no `.rubocop_todo.yml`, and generating one turns a day of cleanup into
  a backlog nobody sees again.
- Markdown, YAML, Bash and workflow files are linted in CI by super-linter. Markdown rules come
  from `.github/linters/.markdown-lint.yml`, not markdownlint's defaults — check that file before
  assuming a rule applies. There is no local Markdown lint wrapper.

## Committing Changes

- Always use the `/commit` slash command when writing or editing a commit message — this includes
  creating new commits, amending commits, and editing commit messages
- Consider using the `/doc-review` slash command after writing or updating a significant amount of
  documentation

## Attribution

`fastererer` was a hard fork of `DamirSvrtan/fasterer` at v0.11.0 and is now a standalone gem. The
README's "Special Thanks" section is the one place that lineage is recorded. Do not reintroduce it
elsewhere: no "Prior art" section in a PR body, no upstream issue or PR references in a commit
message, no `(cherry picked from commit …)` trailer. References to this repository's own issues and
pull requests are fine.

## Branches

- Use short, descriptive kebab-case branch names (e.g. `hash-update-merge-bang-alias`). No type
  prefix (`fix/`, `feat/`), no issue number — name the branch after the change itself.

## Releases

- A version bump must update `lib/fastererer/version.rb` **and** `Gemfile.lock` in the same commit.
  The `Gemfile` uses `gemspec`, so the gem is its own path dependency; CI runs bundler frozen and a
  stale lockfile fails every job at "Set up Ruby" with exit code 16, before any test runs.
- Publishing is gated: the tag push triggers `.github/workflows/release.yml`, whose `rubygems`
  environment requires a human review before the irreversible push to rubygems.org. Never
  auto-approve that gate.
- `rubygems/release-gem` publishes the gem but does not create a GitHub Release — that step is
  separate.

## Code Style Guidelines

- Adhere to the RuboCop conventions in `.rubocop.yml`; `Layout/LineLength` is 100
- Follow Sandi Metz's rules from "Practical Object-Oriented Design in Ruby"
- Follow the [Ruby Style Guide](https://rubystyle.guide/)
- The gemspec's `required_ruby_version` is the supported floor; the matrix in
  `.github/workflows/ci.yml` is what CI actually runs. Read both rather than assuming — and note
  `.ruby-version` is the local development version, not the floor. `.rubocop.yml` sets no
  `TargetRubyVersion`, so RuboCop infers it from the gemspec and already rejects syntax newer than
  the floor; the CI matrix is what catches behavior that differs across the supported range.
- Prefer the shorthand syntax for hashes (`{ x:, y: }`)
- Leave a blank line at the end of every file — RuboCop covers the Ruby files, but nothing
  autocorrects the YAML and Markdown
- Add or update test coverage for any new code that is written — the floors are 100% line and
  branch, so an unexercised guard clause fails the build

## Line Wrapping

- In code and in-repo Markdown, wrap to 100 characters and use the full width — don't wrap comments
  or prose aggressively short. The limit counts indentation and the comment prefix.
- Don't hard-wrap GitHub PR, issue or discussion bodies — GitHub reflows prose to the viewport, so
  manual breaks render raggedly. Write each paragraph on a single line; use real line breaks only
  for bullets, headings, tables and code blocks.
- Commit message bodies still wrap at 72 per git convention. The longer bodies already in this
  repository's history set no precedent.

## Code Comments

- Default to no comment — well-named identifiers cover *what* the code does.
- When a comment is warranted — a hidden constraint reproducible from the current code, such as a
  subtle ordering requirement or a workaround for a live bug elsewhere — keep it to **one short
  line**. Reaching for three or more lines is the signal that the context belongs in the commit
  message or PR description, not in the file.
- A pointer is not a *why*. Naming where something lives ("configuration is in `.simplecov`")
  restates what the reader can already find.
- Don't end a single-sentence or single-phrase comment with a period. Multi-sentence comments
  punctuate normally. Don't "normalize" an existing file's comments by adding periods.
- Don't reference transient planning artifacts (`PLANS.md`, `*_plan.md`, review output, ad hoc
  memos) from library code or specs — they get deleted or renamed.

## Review Scaffolding

Planning and review documents — `PLANS.md`, `*_plan.md`, `*-DOC-REVIEW.md` and the like — are
scaffolding for work in progress, not part of the change they describe.

- **Leave them untracked unless asked.** Don't `git add` one on your own. Once one has been tracked
  deliberately it stays until just before merge: don't flag it as a loose end, or offer to remove
  it, on every subsequent pass.
- **Don't run `/doc-review` over them.** That command is for durable documentation; scaffolding is
  transient and gets rewritten every pass.

## Writing & Copy Conventions

- Use American English spelling everywhere — code, comments, commit messages, PR descriptions,
  issue descriptions and user-facing copy. Write "behavior" not "behaviour", "favor" not "favour",
  "color" not "colour", "organize" not "organise".
- Generally prefer spelling terms out over abbreviating, though it can depend on the context —
  write "abstract syntax tree" in the README, where a reader may be new to static analysis, while
  `AST` reads fine in a comment inside `parser.rb`.
- Restate a convention rather than citing a personal configuration file. Anything a contributor
  needs in order to follow a rule belongs in this file or in `CONTRIBUTING.md`.
