# Empirical program — HEF corpus inventory + first static map (2026-10-24)

Roadmap Campaign 4 iteration, slice 4.10 (AES-NUM-010), opened
under Volmarr's 2026-10-24 order: never stop, never treat a
bounded search's negative as an end, never change the goal.
The public-source study pass (4.5/4.7) graded the CCW layout
and placement census NOT PROVEN *in documents*. This slice
starts the empirical road: real vendor-authored artifacts as
primary evidence.

## Inventory (targeted searches only)

- **One HEF in local reach:**
  `~/hailo10h-twister/custom-hefs/all-MiniLM-L6-v2-hailo10h/minilm-l6-ruvector.hef`
  on Mimir — 11,759,616 bytes, sha256
  `3c5350800349686fe656343f3684159afb396e58de41111b5f4f799ed62e4bcd`.
  An all-MiniLM-L6-v2 embedding network compiled for the
  Hailo-10H, with its `source/` and `recipe/` directories and a
  sample `input.bin` beside it.
- **Study assets in the same tree** (`~/hailo10h-twister/`,
  Volmarr's earlier Hailo workshop): `fork/` and `fork-5.3/`
  (HailoRT source forks — an unmined local copy of the runtime
  sources, including the hef schema), `hailo_model_zoo/`
  (checkout), `compiler-workstation/`, `pyhailort-source/`,
  `unpacked/`, `upstream-genai/`, findings notes.
- **Not found:** any other `.hef` in the repo trees, the Pi's
  home (depth ≤3), `~/aesir-build`, or caches searched. The
  running `hailo-ollama.service`'s model store was not located
  in this pass (its pulled-model artifacts are a named target
  for the next inventory step). A whole-filesystem find on the
  Pi timed out at 60 s and was not repeated (recorded method
  limit).

## First static map of the MiniLM HEF (wire-level)

Method: schema-free protobuf wire walk starting after the
file header, plus 64-bit word statistics per large region
(script `/tmp/hefmap2.py` on Mimir; the artifact was not moved).

- The file header is **56 bytes** (magic `\x01HEF`, version 3);
  the protobuf message starts at byte 56. Its first nested
  message carries field value **103** — the HAILO1XH arch enum
  of field-table group A, observed in a real artifact.
- The walk found **6,183 length-delimited regions**. Largest:
  top-level field `/2` at 56,193 bytes — **high entropy**
  (7,024 words, 6,226 distinct, zero all-zero words):
  weights-class data, not configuration. Repeated `/2/3`
  regions of ~6.8–8.4 KB (dozens) match a per-layer payload
  pattern.
- **No large zero-word (NOP) fields** appear in the big
  regions; the CCW configuration is therefore *not* a big
  contiguous blob in this artifact — it must live in the many
  small structured fields of the network-group core sections,
  identifiable only with the hef schema's field map. The fork
  trees in the corpus hold that schema (`hef.proto`) locally;
  mining it is the next step.

## What this slice establishes / does not

- ESTABLISHED: a real, lawful corpus exists in reach (one
  complete HEF + sources + recipes); the artifact's outer
  anatomy is mapped at wire level; the weights-vs-config
  separation strategy for the differential work is concrete.
- NOT ESTABLISHED: any CCW word's meaning (unchanged); where
  exactly the CCW actions sit in this artifact (next step:
  schema-guided walk from the fork's hef.proto); the census
  (unchanged).
- Next slices: (4.11) schema-guided CCW isolation in the
  MiniLM HEF + word statistics of the isolated region;
  (4.12) differential design — a second artifact differing by
  one known parameter (the recipe tree + model zoo are the
  acquisition routes); (4.13) driver-tree census hunt in the
  local forks.
