# GIT DISCIPLINE — Project Æsir

## Authority

This document governs all version control operations in Project Æsir. It complements ENGINEERING_DOCTRINE.md by specifying exact git procedures. Where the doctrine says "commit with clear messages," this document defines what clear means. Where the doctrine says "push often," this document defines what often means.

Git is not a backup system. It is not a publishing platform. It is the archaeological record of the codebase. Every commit is a stratum. Every branch is a divergent timeline. Every merge is a reconciliation of realities.

Treat it accordingly.

---

## Section One: Branch Structure

### Protected Branches

Two branches are protected. No agent commits directly to either.

**`main`** — Release-ready code. Only receives merges from `development` after full Auditor verification. Every commit on main should theoretically be deployable. If it is not deployable, it does not belong here.

**`development`** — Integration branch. Feature branches merge here after passing CI. This is where the living codebase evolves. It may contain incomplete features, but it must always compile and pass the invariant test suite.

### Feature Branches

All work happens on feature branches branched from `development`.

```bash
git checkout development
git pull origin development
git checkout -b [type]/[domain]-[brief-description]
```

### Branch Naming Convention

```
[type]/[domain]-[brief-description]
```

**Types:**
| Type | Usage |
|------|-------|
| `feat` | New feature or capability |
| `fix` | Bug fix |
| `refactor` | Code restructuring without behavior change |
| `test` | Test additions or improvements |
| `docs` | Documentation changes |
| `chore` | Build, config, tooling |
| `audit` | Verification, capability ledger updates |
| `perf` | Performance optimization |

**Domains:** Use the lowercase domain name from the domain map: `aesir-engine`, `mimir-well`, `bifrost-gate`, `rune-weaver`, `gguf-seer`, `hladgerd`, `mjolnir`, `cross-cutting`.

**Descriptions:** Two to four words, hyphen-separated, lowercase, descriptive of the actual work.

Valid branch names:
```
feat/rune-weaver-bpe-cache
fix/mimir-well-block-alignment
refactor/bifrost-gate-request-parser
test/gguf-seer-edge-cases
docs/architecture-update
audit/capability-ledger-q3-review
perf/mjolnir-attention-kernel
chore/build-config-cleanup
```

Invalid branch names:
```
stuff                          # No type, no domain
fix-stuff                      # Wrong separator
feat/rune weaver/bpe cache     # Spaces, slashes
my-branch                      # meaningless
FEATURE/RUNEWEAVER_BIG_CHANGE  # Screaming, vague
fix/mimir                       # No description
```

### Branch Lifespan

Feature branches are temporary. They exist to deliver a unit of work and then die.

- **Maximum lifespan**: 7 days. If a branch lives longer, it has diverged too far from development and will produce painful conflicts.
- **Stale branches**: Branches with no commits for 14 days are eligible for deletion by the coordinator. The coordinator notifies the owning agent before deletion.
- **Merged branches**: Deleted immediately after successful merge. Do not hoard merged branches.

### Branch Hygiene

One branch accomplishes one thing. Do not mix unrelated changes on the same branch. If you are fixing a bug and simultaneously adding an unrelated feature, you are on two branches pretending to be one.

Split them:
```bash
git stash                           # Save current work
git checkout development
git checkout -b fix/the-bug        # Branch for the bug
# Fix the bug, commit, merge
git checkout development
git checkout -b feat/the-feature   # Branch for the feature
git stash pop                       # Restore feature work
# Continue feature work
```

---

## Section Two: Commit Standards

### What Constitutes a Commit

A commit is a single logical change. It might span multiple files. It might be one line. The criterion is cohesion: does the commit accomplish one identifiable thing?

Good commits:
- "Implement BPE merge rule caching in RuneWeaver"
- "Fix KV cache block alignment calculation in MimirWell"
- "Add regression test for GGUF truncated header parsing"

Bad commits:
- "Various changes" (What changes?)
- "Updates" (Updates to what?)
- "Fix bugs" (Which bugs? How?)
- "WIP" (Work in progress does not belong in history)
- "asdfghjkl" (If you typed this, you are not paying attention)

### Commit Frequency

Commit when:
- A logical unit of work is complete (a function works, a test passes, a file is updated)
- The code compiles and tests pass at the current state
- You are about to switch context or end a session

Do not commit when:
- The code does not compile
- Tests are failing (unless the commit explicitly marks a known-broken state with a TODO)
- You have unrelated changes staged
- You are about to try something experimental (stash instead)

### Commit Message Format

```
[type]: [ imperative description ]

[optional body: explain motivation, approach, and implications]

[optional footer: breaking changes, issue references, attribution]
```

**Rules:**

1. The first line is the subject. Maximum 72 characters. Imperative mood: "Add" not "Added," "Fix" not "Fixed," "Implement" not "Implementation of."
2. The subject stands alone. A reader should understand what the commit does from the subject alone without reading the body.
3. Blank line between subject and body.
4. Body wraps at 80 characters.
5. Body explains why, not what. The diff shows what. The message shows why.
6. Footer preceded by blank line. Contains BREAKING CHANGE notifications, issue refs, or attribution notes.

### Commit Types in Detail

**`feat`** — New feature or capability.
```
feat: implement BPE token caching in RuneWeaver

Adds an LRU cache for encoded token sequences to avoid recomputation
on repeated prompts. Cache keyed by (vocab_hash, text_content) with
configurable max size. Hit ratio logged at debug level.

Updates CAPABILITY_LEDGER: rune_weaver.token_cache → Verified
```

**`fix`** — Bug fix. Must reference the issue or describe the symptom.
```
fix: correct KV cache block alignment in MimirWell

Previous calculation used ceil(token_count / block_size) but did not
account for the padding requirement in the final partial block. This
caused page table index corruption when token_count was not divisible
by block_size.

Discovered during integration test test_multi_request_concurrency.
Regression test added: test_regression_014_block_alignment.mojo
```

**`refactor`** — Code restructuring without behavior change.
```
refactor: extract HTTP request parsing from BifrostGate handler

Moves request parsing logic into separate HttpRequestParser struct
within the bifrost_gate domain. Handler now delegates to parser and
focuses on routing. No behavior change. All existing tests pass.

Motivated by upcoming streaming response work which requires cleaner
separation between request ingestion and response generation.
```

**`test`** — Test additions or improvements.
```
test: add edge case tests for GGUFSeer metadata extraction

Adds tests for:
- Empty metadata section
- Metadata with unknown key types
- Metadata exceeding uint32 size limit
- Unicode string metadata values

All tests use fixtures committed to tests/fixtures/gguf/.
```

**`docs`** — Documentation changes.
```
docs: update AesirEngine INTERFACE.md with session lifecycle methods

Documents create_session, close_session, and get_session_status
methods added in feat/aesir-engine-session-lifecycle. Updates
parameter types and return signatures to match implementation.
```

**`audit`** — Verification or capability ledger changes.
```
audit: downgrade GGUFSeer.tensor_extraction from Verified to Partial

Manual testing revealed that tensor extraction fails on models with
quantization format Q5_K_M. Unit tests only covered Q4_0 and Q8_0.
Downgrade reflects actual capability. Added TODO in TASK_QUEUE.md
for Q5_K_M support.
```

**`chore`** — Build, config, tooling.
```
chore: update Mojo compiler version to 1.0.0 in CI pipeline

Pinned CI to Mojo 1.0.0 stable release. Removed workaround for
compiler bug #1123 which was fixed in 0.26.2.
```

**`perf`** — Performance optimization.
```
perf: vectorize attention score computation in Mjølnir

Replaces scalar dot product loop with SIMD[DType.float32, 8]
operations for query-key score calculation. Measured 2.3x speedup
on 7B Q4 model, 128-context inference.

Benchmark: tests/performance/bench_attention_compute.mojo
Before: 14.2 ms/token | After: 6.1 ms/token
```

### What Never Goes in a Commit

- Secrets, API keys, passwords, tokens
- Build artifacts (*.o, *.exe, *.dll, *.so, build/, target/)
- Editor configuration (.vscode/, .idea/) unless project-shared
- OS-generated files (.DS_Store, thumbs.db, desktop.ini)
- Logs, crash dumps, core files
- Downloaded models or large binary assets
- Personal notes or scratch files

The `.gitignore` file defines these exclusions. If you discover something that should be ignored and is not, add it to `.gitignore` in a separate `chore:` commit.

---

## Section Three: Staging and Atomicity

### Stage With Intent

Never use `git add -A` blindly. Stage files deliberately.

```bash
# Good — stage specific files
git add src/rune_weaver/bpe_encoder.mojo
git add tests/unit/rune_weaver/test_bpe_encoding.mojo
git commit -m "feat: implement BPE merge rule application in RuneWeaver"

# Acceptable — stage a specific directory
git add src/rune_weaver/
git commit -m "..."

# Danger zone — stage everything
git add -A
# Only acceptable if you have verified that every modified file
# belongs in this commit
```

### Atomic Commits

An atomic commit contains exactly the changes needed to accomplish one logical operation. If a commit includes unrelated whitespace fixes alongside a feature implementation, it is not atomic.

If you discover unrelated changes in your working tree while staging:
```bash
git stash --keep-index    # Stash unstaged changes
git commit -m "..."       # Commit only what you staged
git stash pop             # Restore the unrelated changes
# Deal with them separately
```

### Pre-Commit Verification

Before committing, verify:
```bash
# Does it compile?
mojo build src/

# Do tests pass?
mojo test tests/

# What exactly am I committing?
git diff --cached

# Any secrets accidentally staged?
git diff --cached | grep -iE "(password|secret|token|key)" | grep -v "^---" | grep -v "^+++"
```

The last command is paranoid. Paranoia is appropriate when secrets are concerned.

---

## Section Four: Pushing and Syncing

### Push Cadence

Push after:
- Every completed feature or fix (after the commit)
- End of every work session
- Before requesting a peer review
- Before switching machines

Rule of thumb: if losing your local branch would cause more than 30 minutes of rework, push.

### Keeping Branches Current

```bash
# Daily: sync with development
git checkout development
git pull origin development
git checkout feat/my-branch
git rebase development    # Preferred over merge for feature branches
```

Rebase keeps history linear and clean. Merge creates merge commits that clutter the log. For feature branches destined to be squashed on merge, rebase is strictly preferable.

### Rebasing Safely

If your branch has been pushed and others may have pulled it, rebasing rewrites history and creates divergence. Coordinate with anyone who has pulled your branch before rebasing.

For solo feature branches that no one else has pulled:
```bash
git rebase development
# Resolve conflicts if any
git push --force-with-lease origin feat/my-branch
```

Use `--force-with-lease` instead of `--force`. The former refuses to push if someone else has pushed to the branch since you last fetched. The latter blindly overwrites and destroys others' work.

---

## Section Five: Merging and Pull Requests

### When to Request Merge

A feature branch is ready to merge into `development` when:
1. All planned work is complete
2. All tests pass locally
3. The capability ledger is updated if status changed
4. Documentation is updated
5. No merge conflicts exist (rebase onto latest development)
6. The commit history is clean (squash intermediary commits if needed)

### Pull Request Template

```markdown
## PR: [Type] — [Domain] — [Description]

### What This Accomplishes
[Brief summary of the change and its purpose]

### Related Tasks
- TASK_QUEUE ID: [if applicable]
- Closes #[issue number] (if applicable)

### Verification Performed
- [ ] Unit tests pass
- [ ] Integration tests pass (if applicable)
- [ ] Invariant tests pass
- [ ] No absolute paths introduced
- [ ] No single-quote string literals introduced
- [ ] No secrets committed
- [ ] Capability ledger updated
- [ ] Documentation updated
- [ ] Auditor checklist completed (for Verified upgrades)

### Breaking Changes
[List any breaking changes or "None"]

### Test Results
[Paste test output summary or CI badge]

### Notes for Reviewers
[Anything reviewers should pay special attention to]
```

### Squash Merging

Feature branches are squash-merged into development. This compresses all commits on the branch into a single commit on development.

Rationale: intermediary commits on a feature branch (fix typo, address review feedback, reorder imports) are noise. The development branch should show one commit per feature, not seventeen.

Procedure:
```bash
# On development
git merge --squash feat/my-branch
git commit -m "feat: [complete description encompassing all branch work]"
```

The squash commit message should be comprehensive. It summarizes the entire branch, not just the last commit.

### Merge Conflict Resolution

Conflicts are inevitable. Panic is optional.

```bash
git rebase development
# CONFLICT detected in src/example.mojo
```

Resolution procedure:
1. Open the conflicted file. Locate conflict markers (`<<<<<<<`, `=======`, `>>>>>>>`).
2. Understand both sides. What does your branch do? What does development do? Why do they differ?
3. Resolve manually. Do not blindly accept one side. The correct resolution may combine both.
4. Test the resolution: `mojo build src/ && mojo test tests/`
5. Stage the resolved file: `git add src/example.mojo`
6. Continue the rebase: `git rebase --continue`

Never resolve a conflict by deleting one side wholesale without understanding what you are discarding.

### Hotfix Procedure

When a critical bug is found in `main`:

```bash
git checkout main
git checkout -b fix/hotfix-[description]
# Fix the bug
# Test thoroughly
git commit -m "fix: [critical bug description]"
# Merge to main
git checkout main
git merge --no-ff fix/hotfix-[description]
git push origin main
# Merge back to development
git checkout development
git merge --no-ff fix/hotfix-[description]
git push origin development
# Delete the hotfix branch
git branch -d fix/hotfix-[description]
git push origin --delete fix/hotfix-[description]
```

Hotfixes bypass the normal feature branch → development → main flow because timeliness matters. They still require full testing. A hotfix that introduces a new bug is worse than the original.

---

## Section Six: History Management

### The Commit Log Is Documentation

Anyone should be able to run `git log --oneline` and understand the project's evolution:

```text
$ git log --oneline -20
a3f7b2c feat: implement streaming response in BifrostGate
d4e8a1f fix: correct KV cache eviction order in MimirWell
c2b9f33 test: add integration test for end-to-end inference
e7a4d22 refactor: extract tokenizer interface from RuneWeaver
f1c6e88 audit: upgrade rune_weaver.bpe_encoding to Verified
b8d3aab perf: vectorize softmax computation in Mjølnir
9e2f114 docs: update ARCHITECTURE.md with memory flow diagram
3a7c8bb chore: pin Mojo compiler to 1.0.0 in CI
...
```

If your log looks like this, you are succeeding:
```text
$ git log --oneline -20
7a3b2c1 stuff
6d4e8a1 updates
5c2b9f3 more changes
4e7a4d2 WORKING VERSION DO NOT DELETE
3f1c6e8 finally fixed it
2b8d3aa try again
1e2f114 maybe this works
```

### Amend Responsibly

`git commit --amend` modifies the last commit. Use it to fix a mistake in the commit message or add a forgotten file.

```bash
# Forgot to stage a test file
git add tests/unit/new_test.mojo
git commit --amend --no-edit
```

Amend only when the commit has not been pushed. If it has been pushed, amending requires a force-push, which rewrites shared history. Only do this on branches no one else has pulled.

### Interactive Rebase for Cleaning Up

Before merging a feature branch, clean up intermediary commits:

```bash
git rebase -i development
```

Squash typos and fixes into their parent commits. Reorder if logical grouping improves. Remove commits that were experimental and reverted.

Commands in interactive rebase:
- `pick` — Keep this commit
- `squash` — Combine with the previous commit
- `drop` — Remove this commit entirely
- `reword` — Keep the commit but change its message

Warning: Dropping commits is irreversible once the rebase completes. Be certain.

### Never Rewrite Published History

Once a commit is on `main` or `development`, it is permanent. Do not rebase, amend, or force-push to these branches. If a commit on a protected branch is wrong, create a new commit that fixes it.

```bash
# Bad: rewriting history on development
git rebase -i HEAD~5
git push --force origin development

# Good: a fix-forward commit
git revert abc123
git commit -m "fix: revert problematic change from abc123"
git push origin development
```

---

## Section Seven: Tags and Releases

### Version Tags

Tags mark release points. They are immutable.

```bash
git tag -a v0.1.0 -m "Alpha: core inference loop functional, single-request mode"
git push origin v0.1.0
```

Tag format: `v[major].[minor].[patch]`

- **Major**: Architectural overhaul, breaking changes (0.x → 1.x)
- **Minor**: New features, backwards compatible (0.1 → 0.2)
- **Patch**: Bug fixes only (0.1.0 → 0.1.1)

### Release Notes

Each tag has a corresponding release notes file in `docs/releases/`:

```markdown
# Release v0.1.0 — Alpha

## Date
YYYY-MM-DD

## Status
Alpha — not for production use

## Included Capabilities
- GGUF model loading (Q4_0, Q8_0 quantization)
- BPE tokenization (English vocabularies)
- Single-request inference (no batching)
- CPU execution path (no GPU acceleration)
- Ollama-compatible /completion endpoint

## Known Limitations
- No batching (throughput limited to single request)
- No GPU support (CPU-only)
- No streaming responses
- Max context length: 2048 tokens

## Tested Hardware
- AMD Ryzen 9 5900X, 64GB RAM
- Intel i7-12700K, 32GB RAM
```

---

## Section Eight: Emergency Procedures

### Undoing the Last Commit (Not Yet Pushed)

```bash
# Keeps the changes in your working tree
git reset --soft HEAD~1

# Removes the changes from staging but keeps in working tree
git reset --mixed HEAD~1

# Destroys the changes entirely (dangerous)
git reset --hard HEAD~1
```

Use `--soft` when you want to re-commit with a different message or staging. Use `--mixed` when you want to restage selectively. Never use `--hard` unless you are certain the changes are worthless.

### Undoing a Pushed Commit

```bash
git revert abc123
git push origin development
```

`revert` creates a new commit that undoes the changes. It does not rewrite history. Use this for any commit already on a shared branch.

### Recovering a Deleted Branch

```bash
# Find the commit hash before deletion
git reflog
# Locate the last commit on the deleted branch

git checkout -b recovered-branch abc123
```

The reflog records every HEAD movement for 90 days. Deleted branches are recoverable within that window.

### Resolving Accidental Push to Wrong Branch

```bash
# Accidentally pushed feature work to development directly
# Reset development to its previous state
git checkout development
git reset --hard origin/previous-development-hash
git push --force-with-lease origin development

# Then redo the work properly on a feature branch
git checkout -b feat/proper-branch
# Cherry-pick or redo the work
```

This is one of the few cases where force-pushing to a protected branch is justified. Document the incident in a DECISIONS entry.

---

## Section Nine: CI Integration

### CI Pipeline Stages

```
Push → Checkout → Install Mojo → Build → Unit Tests → Invariant Tests → Lint → Report
PR → Checkout → Install Mojo → Build → Full Test Suite → Capability Ledger Check → Report
Merge to Main → Checkout → Install Mojo → Build → Full Test Suite → Tag → Release Notes Check → Report
```

### CI Gates

The CI pipeline blocks merging if:
- Any test fails
- The build produces warnings (configured as errors)
- The capability ledger references features that have no corresponding test
- Absolute paths are detected in committed files
- Single-quote string literals are detected in Mojo files
- The commit message does not follow the required format

### CI Bypass

There is no CI bypass. If CI fails, you fix the problem. You do not circumvent the pipeline.

The only exception is a coordinator-declared emergency hotfix, documented in DECISIONS with rationale.

---

## Section Ten: Common Disaster Scenarios

### Scenario: Agent Committed Secrets

```bash
# Immediately rotate the secret. Assume it is compromised.

# Remove from history (if not yet pushed)
git reset --soft HEAD~1
# Remove the secret from the file
git add .
git commit -m "fix: remove accidentally committed credentials"

# If already pushed, the secret is in history permanently
# Rotate the secret, then purge:
git filter-branch --tree-filter 'rm -f config/secrets.env' HEAD
git push --force origin development
# Document in DECISIONS
```

### Scenario: Massive Merge Conflict Nightmare

```bash
# Abort the merge
git merge --abort

# Rebase interactively in small chunks
git rebase -i development
# Resolve one commit at a time
# Test after each resolution
```

If the conflict is truly intractable, the branch may need to be abandoned and restarted from the current development head. This is not failure. It is acknowledging sunk cost.

### Scenario: Force-Pushed Over Someone Else's Work

```bash
# The victim pulls and discovers their work is gone
git reflog
# Finds their last commit hash

git cherry-pick abc123
# Recovers their work onto the current branch
```

Prevention: always use `--force-with-lease`. Never use `--force`.

### Scenario: Accidental Deletion of development Branch

```bash
# development is protected remotely. Fetch it back:
git fetch origin
git checkout -b development origin/development
```

Protected branches cannot truly be deleted from the remote. Local deletions are recoverable via fetch.

---

## Section Eleven: Quick Reference

```
STARTING WORK:
□ git checkout development && git pull
□ git checkout -b [type]/[domain]-[description]

BEFORE COMMITTING:
□ Code compiles
□ Tests pass
□ git diff --cached reviewed
□ No secrets staged
□ No absolute paths
□ No single quotes

COMMIT MESSAGE:
□ [type]: [imperative subject] (≤72 chars)
□ Blank line
□ Body explains why (wrap ≤80 chars)
□ Footer for breaking changes/issues

PUSHING:
□ git push origin [branch-name]
□ Use --force-with-lease only after rebase on unpublished branches
□ Never force-push to main or development

MERGING:
□ Rebase onto latest development
□ All tests pass
□ PR template filled
□ Squash merge into development
□ Delete merged branch

EMERGENCY:
□ Secrets committed → rotate immediately, purge history
□ Bad commit on main → revert, do not rewrite
□ Lost work → check reflog, 90-day recovery window
```

---

## Closing Principle

Git history is the autobiography of the codebase. Written poorly, it is incomprehensible noise. Written well, it is a narrative that any contributor can read to understand how the system became what it is.

Every commit you write is a sentence in that autobiography. Make it a sentence worth reading.

---

*Last updated: 2026-08-15. Maintained by the Architect role. Changes require review.*

---
