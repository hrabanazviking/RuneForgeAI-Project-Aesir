# TASK_CONTRACT_4.191_RETRY (AES-NUM-191, retry launch)

This contract authorizes exactly ONE replacement launch
for slice 4.191. It does not change the slice's scope,
tests, or populations in any way: the scope is exactly
`docs/TASK_CONTRACT_4.191.md` (i)–(iii) — the B-only act
at B 674 in full; the B-only acts at B 735 and B 736 in
full, with ranks 746–748 in rank order; and the shared
run-101 act (3446784, 24, 2) at A 682 / B 675 in full.
Any law NOT PROVEN unless the numbers prove it; never
invent one.

Why a new contract exists: the single launch authorized
by TASK_CONTRACT_4.191 (tmux h191, launched 2026-10-30
07:07:01 EDT, contract argv, glob order, MiniLM last)
ran the full inherited corpus walk, the controls, arm
(i) and arm (ii) in part, then crashed with exit 1
(hef191.err 871 B): IndexError in the worker-authored
'B735 B736 OFFSET GAPS' print in sections191 — its
range(745, 751) asks for the successor of rank 750 in
a context of 751 acts (ranks 0–750), so rr + 1 = 751
is out of range. The bug is in the NEW 4.191 section
only, not in any inherited code. hef191.out (52,245
lines / 9,691,668 B) is retained on Mimir; there was
no DONE191. That launch is closed and must never be
repeated under TASK_CONTRACT_4.191.

Retry terms (the AES-NUM-105/150 one-line-patch
precedent):
- The ONLY code change: in sections191.py, the
  'B735 B736 OFFSET GAPS' range(745, 751) becomes
  range(745, 750) (gaps for ranks 745–749, each to
  its successor rank, the last being rank 750).
  arms191 and hef191 are rebuilt from the same
  lineage (hef190.py + patched arms191) and must
  compile on the VM and on Mimir; all shas recorded.
- Exactly ONE bounded host-side child under this
  contract: check `tmux ls` + `ps` on Mimir for an
  existing hef191r/h191r child BEFORE launching.
- Launch in detached tmux (session h191r) with
  unbuffered output (`python3 -u`), output to
  hef191r.out, errors to hef191r.err, and the shell
  writes the child's exit code to hef191r.exit.
- Corpus argv exactly as in TASK_CONTRACT_4.191:
  ~/.local/share/hailo-ollama/models/blob/sha256_*
  (glob order) + MiniLM at
  ~/hailo10h-twister/custom-hefs/all-MiniLM-L6-v2-hailo10h/minilm-l6-ruvector.hef
  last.
- Success = DONE191 as the last line of hef191r.out,
  hef191r.exit == 0, hef191r.err empty. If the child
  fails again, this batch closes: write up the
  negative result honestly under AES-NUM-191 and do
  NOT launch a third child without Volmarr's or the
  main thread's direction.

Host/artifact analysis only on Mimir — no physical child.
