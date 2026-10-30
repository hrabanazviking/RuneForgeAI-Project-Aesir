# TASK_CONTRACT_4.210_RETRY (AES-NUM-210, retry launch)

This contract authorizes exactly ONE replacement launch
for slice 4.210. It does not change the slice's scope,
tests, or populations in any way: the scope is exactly
`docs/TASK_CONTRACT_4.210.md` (i)–(iii) — the A-only act
at A 734 in full; the B-only act at B 736 in full; and
the shared resync act at A 737 / B 739 in full, with the
resync tests (run-102 membership and ordinal; whether
the identical-order sequence resumes after the
divergence, and exactly how far the resumed sequence
runs). Any law NOT PROVEN unless the numbers prove
it; never invent one.

Why a new contract exists: the single launch authorized
by TASK_CONTRACT_4.210 (tmux h210, launched 2026-10-30
12:26:23 EDT, contract argv, glob order, MiniLM last)
ran the full inherited corpus walk, the controls (all
EXACT), arm (i), arm (ii) and arm (iii) in part, then
crashed with exit 1 (hef210.err 489 B): IndexError in
the worker-authored 'RESYNC EXTENDED' print in
sections210 — its range(737, 757) asks for A indices
up to 756 in a context of 749 acts (indices 0–748;
CONTEXT SIZES in the crashed run: A acts 749, B acts
751). The bug is in the NEW 4.210 section only, not in
any inherited code. hef210.out (55,526 lines /
10,159,324 B, sha256 65a20990…) is retained on Mimir;
its first 55,401 lines differ from hef209.out in
exactly one line (line 41611, frozenset element order
only — the AES-NUM-150 variance); its partial section
(125 lines / 18,348 B, sha256 4c07c6b9…) was read in
full on-device. There was no DONE210. That launch is
closed and must never be repeated under
TASK_CONTRACT_4.210.

Retry terms (the AES-NUM-191 one-line-patch precedent):
- The ONLY code change: in sections210, the extended
  resync window range(737, 757) / range(739, 759)
  becomes range(737, 749) / range(739, 751) — exactly
  to the end of both context lists, as measured in
  the crashed run — and its print label becomes
  'A 737-748 / B 739-750'. arms210r and hef210r are
  rebuilt from the same lineage (hef209.py +
  patched arms210r) and must compile on the VM and
  on Mimir; all shas recorded.
- Exactly ONE bounded host-side child under this
  contract: check `tmux ls` + `ps` on Mimir for an
  existing hef210r/h210r child BEFORE launching.
- Launch in detached tmux (session h210r) with
  unbuffered output (`python3 -u`), output to
  hef210r.out, errors to hef210r.err, and the shell
  writes the child's exit code to hef210r.exit.
- Corpus argv exactly as in TASK_CONTRACT_4.210:
  ~/.local/share/hailo-ollama/models/blob/sha256_*
  (glob order) + MiniLM at
  ~/hailo10h-twister/custom-hefs/all-MiniLM-L6-v2-hailo10h/minilm-l6-ruvector.hef
  last.
- Success = DONE210 as the last line of hef210r.out,
  hef210r.exit == 0, hef210r.err empty. If the child
  fails again, this batch closes: write up the
  negative result honestly under AES-NUM-210 and do
  NOT launch a third child without Volmarr's or the
  main thread's direction.

Host/artifact analysis only on Mimir — no physical child.
