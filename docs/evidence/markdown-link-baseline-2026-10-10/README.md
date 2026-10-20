# Active Markdown link baseline — 2026-10-10

AES500-052 records the tracked documentation corpus before link validation is
implemented or enforced.

## Bound scope and tools

- Repository revision: `dc7b6afc8a98bd53fa9591e462d8d0a83da59d57`.
- Source selection: tracked root, `docs/`, and `aesir_engine/` Markdown,
  excluding `docs/evidence/**` and `docs/historical/**`.
- Markdown-it parser: `markdown-it-py` 4.2.0 from the repository Pixi lock,
  CommonMark preset.
- Runtime: Python 3.14.6 from the repository Pixi environment.
- Census tool SHA-256:
  `cb5dbe0c3220710e7a9c5b54e79b3b51fd6987b52f3c2bca966d71bc052692e3`.
- Census JSON SHA-256:
  `84227553479a6ac4db45e58d120169077b0e312868f194acf34cc636e8f4ed20`.
- Two consecutive runs produced byte-identical JSON. Reproduce with
  `pixi run python scripts/census_markdown_links.py`.

## Summary

- 297 Markdown source files contain 976 CommonMark inline links and images:
  951 links and 25 images.
- 861 destinations are repository-local; 115 use external schemes and were not
  fetched.
- The current candidate heading/explicit-anchor inventory reports nine local
  missing-fragment references, all in the table of contents of
  `Complete_Mojo_Programming_Language_Guide.md`, where nine destination numbers
  are one greater than the corresponding heading numbers.
- No missing local file targets or root escapes were observed in this corpus.

The JSON retains per-file SHA-256 values, link kind, source path/line, literal
destination, classification and every detected problem. The census is a
pre-enforcement inventory; its candidate anchor algorithm is not yet the
accepted validator interface. These nine old fragment mismatches must remain
visible as baseline debt when enforcement is later integrated.
