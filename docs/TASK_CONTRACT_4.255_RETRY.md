# TASK_CONTRACT_4.255_RETRY (AES-NUM-255, retry launch)

This contract authorizes exactly ONE replacement launch
for slice 4.255. It does not change the slice's scope,
tests, or populations in any way: the scope is exactly
`docs/TASK_CONTRACT_4.255.md` (i)–(iii) — the closing-run
cumulative-remaining-minus-remaining difference sequence
in full; the distinct differences in full with positions
and counts; and the gap cumulative-remaining difference
sequence in full, checked against AES-NUM-254 and
AES-NUM-245. Any law NOT PROVEN unless the numbers prove
it; never invent one.

Why a new contract exists: the single launch authorized
by TASK_CONTRACT_4.255 (tmux h255, launched 2026-10-31
03:14:32 EDT, contract argv, glob order, MiniLM last)
ran the full inherited corpus walk, the controls (all
EXACT), arm (i) and arm (ii) in full, then crashed with
exit 1 (hef255.err 1,549 B): NameError in the
worker-authored 'GAP POSITION' print in sections255 —
it references expGapCumRem255 inside the gap loop, but
that name is defined after the loop in the inherited
layout. The bug is in the NEW 4.255 section only, not in
any inherited code. hef255.out (58,881 lines /
10,700,426 B, sha256 c0e48301…) is retained on Mimir;
its first 58,847 lines differ from hef254.out in
exactly one line (line 41611, frozenset element order
only — the AES-NUM-150 variance); its partial section
(34 lines / 11,519 B, sha256 700ae8b2…) was read in
full on-device: arm (i) printed the difference sequence
[0, 15, 28, 40, 52, 61, 67, 70] with all tests True and
arm (ii) printed eight distinct differences with counts
summing to 8. There was no DONE255. That launch is
closed and must never be repeated under
TASK_CONTRACT_4.255.

Retry terms (the AES-NUM-191 one-patch precedent):
- The ONLY code change: in sections255, define
  expGapCumRem255 = [3, 6, 9, 12, 14, 15, 15] before
  the gap loop (alongside the gapDiffCR255 /
  expGapDiffCR255 definitions). The identical
  post-loop definition remains, harmless. arms255r and
  hef255r are rebuilt from the same lineage (hef254.py
  + patched arms255r) and must compile on the VM and
  on Mimir; all shas recorded.
- Exactly ONE bounded host-side child under this
  contract: check `tmux ls` + `ps` on Mimir for an
  existing hef255r/h255r child BEFORE launching.
- Launch in detached tmux (session h255r) with
  unbuffered output (`python3 -u`), output to
  hef255r.out, errors to hef255r.err, and the shell
  writes the child's exit code to hef255r.exit.
- Corpus argv exactly as in TASK_CONTRACT_4.255:
  ~/.local/share/hailo-ollama/models/blob/sha256_*
  (glob order) + MiniLM at
  ~/hailo10h-twister/custom-hefs/all-MiniLM-L6-v2-hailo10h/minilm-l6-ruvector.hef
  last.
- Success = DONE255 as the last line of hef255r.out,
  hef255r.exit == 0, hef255r.err empty. If the child
  fails again, this batch closes: write up the
  negative result honestly under AES-NUM-255 and do
  NOT launch a third child without Volmarr's or the
  main thread's direction.

Host/artifact analysis only on Mimir — no physical child.
