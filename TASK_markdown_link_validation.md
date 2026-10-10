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
- Candidate syntax: CommonMark inline links and images, including reference
  uses/definitions, after excluding fenced code and inline code spans.
- Parser identity: `markdown-it-py` 4.2.0, CommonMark preset, through the
  repository's pinned Pixi environment.
- Test owner: `scripts/test_check_doc_drift.py` or a dedicated focused test.

## Invariants

- Every local destination resolves relative to the source document and remains
  within the repository root. Percent-encoded path characters are decoded
  before filesystem resolution. Query strings do not affect file lookup.
- A local target must exist as a file or directory. A directory destination
  without a fragment is valid; a fragment on a directory destination is not a
  document anchor and fails validation.
- Fragment-only links target the source document. File-plus-fragment links
  validate the target file first, then the fragment against an explicit HTML
  `id`/`name` anchor or a heading anchor in that file. Heading anchor
  generation follows the repository's pinned GitHub-compatible algorithm,
  including punctuation and duplicate-slug behavior, documented in the
  interface slice.
- GitHub-compatible heading anchors lowercase the heading text, replace spaces
  with hyphens, remove other whitespace and punctuation, and strip Markdown
  formatting before slugging. Duplicate slugs receive `-1`, `-2`, and later
  numeric suffixes in source order. Explicit HTML `id`/`name` anchors are
  matched exactly and take precedence for their literal values.
- URI destinations with an explicit non-file scheme (`http`, `https`, `mailto`,
  `data`, and other schemes) are external and are not fetched or validated.
  Protocol-relative URLs are external as well.
- `file:` URIs are not repository-relative destinations. The pinned CommonMark
  parser does not emit them as accepted link tokens; if a future parser does,
  they fail closed rather than being read from the host filesystem.
- Malformed or empty local destinations are reported with source path and
  one-based line number when the CommonMark parser emits a link/image token.
  Syntactically unrecognized text that resembles an incomplete Markdown link is
  outside this parser contract. Diagnostics are stable and source ordered.
- The checker is read-only, has no network dependency, and does not rewrite
  links, anchors, or Markdown.
- Repository-wide enforcement remains opt-in until AES500-052 records preexisting
  failures and later slices define how baseline debt is surfaced without
  hiding newly introduced broken links.

## Exclusions

- No network reachability, redirect, TLS, or remote-anchor checking.
- No parsing of arbitrary HTML links, angle-bracket autolinks, or embedded raw
  HTML in this first contract unless later slices add an explicit interface.
- No validation of code examples that happen to contain Markdown-like syntax.
- No filesystem traversal outside the repository root and no following links
  to external paths.

## Acceptance commands

```sh
pixi run python scripts/test_check_markdown_links.py
pixi run python scripts/check_markdown_links.py --check --baseline-json docs/evidence/markdown-link-baseline-2026-10-10/link-census.json
```

Without `--baseline-json`, `--check` exits nonzero when it finds any issue. With
the pinned baseline, exact unchanged known failures are printed as `BASELINE`
and do not fail the command; new or excess issue signatures remain `ERROR` and
produce exit code 1. A malformed or unreadable baseline fails closed with exit
code 2.

AES500-052 measured this active-doc set and link baseline. AES500-053 pins
helper APIs and anchor rules; later slices add implementation and evidence
without claiming coverage for excluded syntax.
