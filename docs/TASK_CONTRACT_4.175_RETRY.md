# TASK_CONTRACT_4.175_RETRY (AES-NUM-175, retry launch)

This contract authorizes exactly ONE replacement launch
for slice 4.175. It does not change the slice's scope,
tests, or populations in any way: the scope is exactly
`docs/TASK_CONTRACT_4.175.md` (i)–(iii) — the head's
twelve non-417-family positions in full (including the
diff-0 identity positions 9 and 18, each against the
position below it); runs 84, 87 and 88 in full; runs 80
and 81 in full. Any law NOT PROVEN unless the numbers
prove it; never invent one.

Why a new contract exists: the single launch authorized
by TASK_CONTRACT_4.175 (tmux h175, launched 2026-10-30
01:07:38 EDT, contract argv, glob order, MiniLM last)
died uncertainly during its silent corpus walk. At
01:12 EDT the tmux session and the process were gone;
hef175.out and hef175.err were both 0 bytes and no
hef175.exit was ever written. No OOM in the kernel
journal; device memory healthy (14 GB available).
Cause NOT ESTABLISHED. That launch is closed and must
never be repeated under TASK_CONTRACT_4.175.

Retry terms:
- The script is the already-crossed hef175.py verbatim
  (sha256 c5f45c73afee1834fb2b805e3130823b7ba91e5f8f7cc5045ba55de63b503a2d,
  1,099,709 B; arms175 sha256 42a5a827…, 11,521 B),
  copied on-device to hef175r.py with identical sha256 —
  no code change, no re-crossing unless the on-device
  sha fails to match the VM.
- Exactly ONE bounded host-side child under this
  contract: check `tmux ls` + `ps` on Mimir for an
  existing hef175r/h175r child BEFORE launching.
- Launch in detached tmux (session h175r) with
  unbuffered output (`python3 -u`) so completed sections
  survive even if the child dies again, output to
  hef175r.out, errors to hef175r.err, and the shell
  writes the child's exit code to hef175r.exit.
- Corpus argv exactly as in TASK_CONTRACT_4.175:
  ~/.local/share/hailo-ollama/models/blob/sha256_*
  (glob order) + MiniLM at
  ~/hailo10h-twister/custom-hefs/all-MiniLM-L6-v2-hailo10h/minilm-l6-ruvector.hef
  last.
- Success = DONE175 as the last line of hef175r.out,
  hef175r.exit == 0, hef175r.err empty. If the child
  dies again with no output, this batch closes too:
  write up the negative result honestly under
  AES-NUM-175 and do NOT launch a third child without
  Volmarr's or the main thread's direction.

Host/artifact analysis only on Mimir — no physical child.
