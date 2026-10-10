# AES500-051 — documentation link and anchor validation contract

## Objective

Define a local, deterministic check for broken Markdown links in tracked
documentation. The checker must validate repository-owned paths and fragments
without network access or modifications to source documents.

## Owner and inputs

- Primary owner: `scripts/check_doc_drift.py` and a dedicated helper module if
  the interface slice establishes one.
- Input set: tracked UTF-8 Markdown files at repository root and below `docs/`
  or `aesir_engine/`, excluding `docs/evidence/**` and `docs/historical/**`.
  Other tracked Markdown such as task, interface, and component docs remains in
  scope. Source-relative link resolution is rooted at the containing document.
- Candidate syntax: CommonMark inline links and images with literal inline
  destinations, after excluding fenced code and inline code spans.
- Test owner: `scripts/test_check_doc_drift.py` or a dedicated focused test.

## Invariants

- Every local destination resolves relative to the source document and remains
  within the repository root. Percent-encoded path characters are decoded
  before filesystem resolution. Query strings do not affect file lookup.
- A local target must exist and be a regular file. A link ending in `/` may
  target an existing directory only when it contains `README.md` (the README is
  the implied document target).
- Fragment-only links target the source document. File-plus-fragment links
  validate the target file first, then the fragment against an explicit HTML
  `id`/`name` anchor or a heading anchor in that file. Heading anchor
  generation follows the repository's pinned GitHub-compatible algorithm,
  including punctuation and duplicate-slug behavior, documented in the
  interface slice.
- URI destinations with an explicit non-file scheme (`http`, `https`, `mailto`,
  `data`, and other schemes) are external and are not fetched or validated.
  Protocol-relative URLs are external as well.
- Malformed or empty local destinations are reported with source path and
  one-based line number. Diagnostics are stable and source ordered.
- The checker is read-only, has no network dependency, and does not rewrite
  links, anchors, or Markdown.
- Repository-wide enforcement remains opt-in until AES500-052 records preexisting
  failures and later slices define how baseline debt is surfaced without
  hiding newly introduced broken links.

## Exclusions

- No network reachability, redirect, TLS, or remote-anchor checking.
- No parsing of arbitrary HTML links, autolinks, reference-style definitions,
  or embedded raw HTML in this first contract unless later slices add an
  explicit interface.
- No validation of code examples that happen to contain Markdown-like syntax.
- No filesystem traversal outside the repository root and no following links
  to external paths.

## Acceptance commands

```sh
python3 scripts/test_check_doc_drift.py
python3 scripts/check_doc_drift.py
```

AES500-052 will measure this active-doc set and link baseline and test the
scope against actual repository syntax. AES500-053 pins helper APIs and anchor
rules before implementation; later slices may narrow unsupported syntax based
on the observed inventory, but must not silently claim coverage for exclusions.
