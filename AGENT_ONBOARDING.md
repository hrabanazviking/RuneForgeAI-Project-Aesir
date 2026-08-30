# AGENT ONBOARDING — Project Æsir

(AGENT_ONBOARDING.md)

## Read This First

You are an AI agent about to contribute to Project Æsir. Before you touch a single file, read this document completely. It will take you three minutes. Skipping sections guarantees you will produce work that gets reverted.

This is not a tutorial. This is not a welcoming message. This is an operational briefing that translates project law into immediate action.

---

## What Project Æsir Is

Project Æsir is an experimental Mojo LLM inference engine. Its verified vertical
slice loads one pinned GGUF v3 Llama F16 model, uses a contiguous request KV
cache, tokenizes with a Mojo BPE tokenizer, and executes locally on a Linux CPU.
GPU/NPU execution, PagedAttention, and Ollama-compatible HTTP inference are
roadmap capabilities, not current behavior.

The project runs entirely on local hardware. No cloud calls. No telemetry. No external runtime dependencies beyond Mojo's standard library and the system's GPU drivers.

The goal is performance parity with llama.cpp and vLLM while maintaining a codebase that is smaller, more auditable, and built in a single language from tokenizer to HTTP handler.

---

## What Project Æsir Is Not

It is not a Python project. If your instincts tell you to reach for numpy, requests, flask, or pytorch, suppress them. Mojo provides equivalent primitives. Use them.

It is not a research prototype. It is production-track infrastructure. Every function should be written as if it will run on someone's desktop for twelve hours straight without crashing.

It is not a playground for experimental language features. Mojo evolves rapidly. Stick to stable, documented language constructs. If a feature landed in the last point release, treat it with caution.

It is not a democracy. The ENGINEERING_DOCTRINE.md is law. Architectural decisions go through review. You implement according to the existing structure, or you propose changes through the DECISIONS process.

---

## Required Reading

Before writing any code, read these files in order:

1. **`ENGINEERING_DOCTRINE.md`** — The cardinal laws, domain map, code standards, testing requirements. This is the constitution. Ignorance of it is not an excuse.

2. **`CAPABILITY_LEDGER.md`** — The honest accounting of what works, what is partial, what is scaffold, and what is missing. This tells you where the project actually stands versus where it claims to stand.

3. **`TODO.md`** — Canonical current work priorities. Do not invent your own tasks unless you have identified an unlisted critical issue.

4. **`ARCHITECTURE.md`** — System structure and domain relationships. Understand how data flows from HTTP request to tokenized input to inference execution to streamed response.

5. **`docs/DOMAIN_MAP.md`** — What each module owns and what it does not own. Boundary violations are the most common cause of architectural rot.

6. **`DEVLOG.md`** — Read the last five entries. This gives you recent context: what was attempted, what succeeded, what failed, what was discovered.

7. **The `INTERFACE.md` of any domain you plan to touch** — Know the public API before you modify implementation. Breaking an interface contract silently is a cardinal offense.

---

## The Taboo List

These actions will get your work reverted without debate:

- Submitting partial files or pseudocode as if they were complete implementations
- Returning hardcoded or mocked responses from functions that should perform real computation
- Using absolute file paths anywhere in code, configs, tests, or documentation
- Leaving integrations incomplete (calling a function that does not exist, implementing a function nothing calls)
- Hardcoding settings, data, or configuration values in source code instead of data files
- Using single quotes for string literals (double quotes only, always, everywhere)
- Crossing domain boundaries without going through published interfaces
- Claiming a feature works without test evidence in the capability ledger
- Committing directly to main or master branch (use feature branches)
- Pushing without running the test suite first
- Changing documentation without updating it to match the actual code state
- Introducing external dependencies without checking DEPENDENCY_POLICY.md
- Renaming public interfaces without updating all consumers in the same commit
- Ignoring the capability ledger when discovering that a feature is less complete than claimed

---

## Current Project State Assessment

As of the last capability ledger update, assess the project's maturity by reading the ledger directly. The general expectation is:

- **Architecture**: largely defined. Domain boundaries exist. Module skeletons are present.
- **Implementation**: uneven. Some domains have verified functionality. Others are scaffold or partial. Some are missing entirely.
- **Testing**: incomplete. Verified features have tests. Everything else does not.
- **Documentation**: present but perpetually at risk of drift. The Scribe role exists to fight this.

Do not assume the project is further along than the ledger claims. Do not assume it is less capable either. Read the ledger and trust it.

---

## How to Begin Work

### Step One: Orient Yourself

After completing the required reading, answer these questions privately:

- Which domain am I working in?
- What is the current status of that domain in the capability ledger?
- What interface does it publish?
- What does it depend on?
- What depends on it?

If you cannot answer all five questions, you are not ready to write code. Read more.

### Step Two: Select a Task

Open `TODO.md`. Find a task that:
- Matches the domain you have oriented to
- Is marked as high priority or blocking
- Falls within your current role's competence

If no tasks match, do not invent one. Report that the queue lacks suitable work for your current role and wait for guidance.

### Step Three: Adopt a Role

Identify which Mythic Engineering role you are fulfilling:

- **Skald** if you are defining vision, naming, or philosophy
- **Architect** if you are defining boundaries, ownership, or structure
- **Cartographer** if you are mapping dependencies or assessing impact
- **Forge Worker** if you are writing implementation code
- **Auditor** if you are verifying, testing, or reviewing
- **Scribe** if you are documenting or preserving continuity

State your role at the top of your DEVLOG entry. This is not vanity. It is operational clarity.

### Step Four: Create a Branch

```bash
git checkout main
git pull --ff-only
git checkout -b feat/[domain]-[brief-description]
```

Branch names follow this pattern. No exceptions.

### Step Five: Implement

Follow the Mojo code standards from the doctrine. Write complete functions. Handle errors. Comment the why. Use double quotes. Respect domain boundaries.

Run tests after every meaningful change:

```bash
mojo test tests/
```

### Step Six: Verify

Before claiming completion:

1. Run the full test suite. All tests must pass.
2. Manually exercise the feature if possible.
3. Check for absolute paths: `grep -rn "/" $(pwd) --include="*.mojo" | grep -v "//"`
4. Verify no single-quote string literals snuck in: `grep -rn "'" --include="*.mojo"`
5. Confirm all imports resolve.
6. Confirm no orphaned functions exist (functions with no callers, unless explicitly public API).

### Step Seven: Update the Capability Ledger

If your work changes the status of any feature, update `CAPABILITY_LEDGER.md` in the same commit. Be honest. If you implemented half of a feature, mark it Partial, not Verified.

### Step Eight: Document

Update any documentation that references the code you changed. Write a DEVLOG entry. If the change is architecturally significant, add a DECISIONS entry.

### Step Nine: Commit and Push

```bash
git add -A
git commit -m "[type]: [description]"
git push origin feat/[branch-name]
```

Commit types: `feat`, `fix`, `refactor`, `test`, `docs`, `chore`, `audit`.

### Step Ten: Report

Inform the human coordinator of:
- What was accomplished
- What was verified
- What risks or discoveries emerged
- What should be tackled next

---

## Communication Expectations

When reporting to the human coordinator:

- Be concise. State what was done, what was verified, what failed, and what is next. No preamble. No throat-clearing. No "I hope this helps."
- Be honest. If something did not work, say so. If you are uncertain, say so. False confidence is worse than acknowledged ignorance.
- Be specific. "Fixed the tokenizer" is useless. "Implemented BPE merge rule application in RuneWeaver.apply_merges(), verified with 12 unit tests covering ASCII and Unicode inputs" is useful.
- Use the DEVLOG format. It exists for a reason.

When commenting in code:

- Explain why, not what.
- Reference ticket numbers or task IDs when relevant.
- Use Norse cosmological metaphors where they aid comprehension, not where they obscure it.

When updating documentation:

- Match the existing tone and structure.
- Do not editorialize. Documentation is not a blog post.
- Cross-reference related documents by filename.

---

## When You Are Unsure

Uncertainty is normal. Guessing is not.

If you do not know:
- Which domain owns a piece of functionality, consult `docs/DOMAIN_MAP.md`
- Whether a feature is implemented, consult `CAPABILITY_LEDGER.md`
- What an interface expects, consult the relevant `INTERFACE.md`
- Whether a change is safe, consult `ARCHITECTURE.md`
- What the project priorities are, consult `TODO.md`

If the documents do not answer your question, escalate to the human coordinator. Frame the question precisely: "I need to implement X. Domain map suggests it belongs to Y, but Y's interface does not expose the needed capability. Should I extend Y's interface or create a new domain?"

Precise questions get precise answers. Vague questions get nothing.

---

## The Five-Minute Self-Test

Before you write your first line of code, confirm you can answer these questions:

1. What is Project Æsir? (One sentence)
2. What language is it written in? (One word)
3. What are the cardinal laws? (Name at least three)
4. What domain will you work in? (One name)
5. What is the current status of that domain? (Capability ledger status)
6. What task will you accomplish? (Task queue ID and description)
7. What role are you adopting? (One name)
8. Where do tests live? (Path)
9. What commit message format is required? (Show the pattern)
10. What do you do before claiming a feature is Verified? (Three items minimum)

If you stumble on any of these, go back and re-read. The thirty seconds you spend now saves thirty minutes of rework later.

---

## Final Warning

This project rewards competence and punishes carelessness equally. The capability ledger does not forgive. The test suite does not negotiate. The domain boundaries do not bend because you found a shortcut.

Build like the machine is listening. Because it is. And it never lies.

Welcome to Project Æsir. Read the doctrine. Pick a task. Make it real.

---

*Last updated: 2026-08-15. Maintained by the Architect role. Changes require review.*
