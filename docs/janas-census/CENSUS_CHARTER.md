# Janas Road — Census Charter and Source Register (J-001)

**Slice:** J-001, Part I — The Census and the Concordance.
**Roadmap:** `~/workspace/your_files/aesir/AESIR_JANAS_CLEANROOM_ROADMAP_2026-10-31.md`.
**Executed:** 2026-10-31 (retrieval date for every source below).
**Worker discipline:** clean-room. Janas is GPL-3.0; Aesir takes no taint. Behaviour is studied from public documentation only. No Janas source file was opened at any point in Part I — the only network fetches made were the raw-markdown documents in the register below.

## Permitted sources (the census ground) — all retrieved 2026-10-31

Base: `https://raw.githubusercontent.com/prabanta-dev/janas/main/`

| # | Document | Path | Bytes (as fetched) | Used by |
|---|---|---|---|---|
| 1 | README | `README.md` | 34,907 | J-002–J-011 (headline tables, NPU, placement, measurement method) |
| 2 | Features | `docs/features.md` | 21,871 | J-002, J-004–J-007, J-011 |
| 3 | Chat | `docs/chat.md` | 31,487 | J-003, J-006, J-008 |
| 4 | Serving | `docs/serving.md` | 40,436 | J-009 |
| 5 | Tools | `docs/tools.md` | 4,016 | J-010 |
| 6 | Models (getting) | `docs/models.md` | 15,886 | J-008, J-010, J-011 |
| 7 | Library | `docs/library.md` | 12,677 | J-010 |
| 8 | Hardware | `docs/hardware.md` | 11,647 | J-008 (bench), J-011 |
| 9 | Code completion | `docs/code-completion.md` | 7,602 | J-009 |
| 10 | Reports | `docs/reports.md` | 5,387 | J-011 (cross-machine evidence) |
| 11 | Models & licences | `MODELS.md` | 23,004 | J-010, J-011 (fingerprints, conversion recipe) |
| 12 | Install | `INSTALL.md` | 9,919 | J-003, J-004, J-005 (requirements, env levers) |
| 13 | ChangeLog | `ChangeLog.md` | 328,019 | chronology cross-check (newest entry 2026-10-30) |

## Forbidden sources (never opened)

Everything under `src/`, `include/`, `tests/`, `examples/` (code), and the `tools/` directory as code. Note the trap the roadmap names: `docs/tools.md` the *document* is permitted and was read; tool *code* was not. Header files named inside `docs/library.md` (e.g. `include/janas/llm.h`) were **not** fetched — the library census rests on the document's own description of the API surface.

## Census method

- One row per documented behaviour: name, what it does, the document that proves it, and Janas's own published numbers where it publishes them.
- Janas's numbers are **its** numbers, measured on its development laptop (Intel Core Ultra 9 185H, 32 GB, NVMe, Debian 13 — README "The machine it grew on"). They are recorded as *published claims*, never as Aesir facts, and never as targets Aesir has met.
- Where the documentation disagrees with the roadmap's opening summary, the documentation wins and the difference is recorded in the census (three such cases: the services family, cache-conditional expert dropping, and the breadth of the server surface — see CENSUS.md §0).
- A behaviour the documents do not establish is recorded NOT DOCUMENTED, never filled in from the source (which stays unopened) or from imagination.
- J-012 re-measures Aesir from the tree and the 204 state file; every HAVE/PARTIAL claim cites its file or run.

## Artefacts of Part I

- `CENSUS.md` — the census table (J-002–J-011).
- `AESIR_LEDGER_CROSSCHECK.md` — Aesir's measured truth (J-012).
- `DELTA_TABLE.md` — the graded delta (J-013), frozen as the Concordance at J-014.
- `GATE_RECORD.md` — the Part I gate (J-014).
