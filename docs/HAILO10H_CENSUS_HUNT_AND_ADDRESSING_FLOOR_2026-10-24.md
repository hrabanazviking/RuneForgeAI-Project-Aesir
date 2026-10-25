# Census hunt (driver trees) + an empirical addressing floor (2026-10-24)

Roadmap Campaign 4 iteration, slice 4.14 (AES-NUM-014),
attacking R3 (the placement census AES-NUM-007 graded NOT
PROVEN in documents) from two new directions.

## Direction 1 — the local driver trees: NEGATIVE, bounded

The twister forks (`fork/`, `fork-5.3/`) are the
hailort-drivers transport trees (common + linux: PCIe/VDMA,
firmware operation, resources). Bounded greps for
cluster/subcluster/APU/core census constants — including the
struct headers (`soc_structs.h`, `hailo_resource.h`) — return
**nothing**. In hindsight this is principled, not unlucky:
the host transport driver moves DMA and firmware commands;
the compute fabric's census lives in firmware and the
compiler, not here. **Corpus class exhausted:** the census
will not come from host driver source. Its remaining roads
are firmware-side material, patents — and the artifact
itself, which paid out immediately:

## Direction 2 — addressing floor from the artifact: MEASURED

Per the pinned schema, `ProtoHEFTrigger` field 2 is
`trigger_lcu` = {cluster_index=1, lcu_index=2}. The MiniLM
HEF carries **286 LCU triggers** (plus 6 none, 13
data-sent). Extracting the pairs (a pair is counted only
when both fields are serialized; proto3 elides zeros, so
index 0 appears as absence and the counts are partial):

- **cluster_index observed: 1, 2, 3, 4** (87/88/50/15 of the
  240 fully-serialized pairs), plus elided 0s — this one
  small embedding network addresses **at least clusters
  0–4 (≥5 clusters)**.
- **lcu_index observed: 1 through 15**, near-uniform
  (14–19 each), plus elided 0s — **at least LCUs 0–15
  (≥16 per cluster)** are addressed.

**Grade: EMPIRICAL LOWER BOUND.** A network uses only what
it needs, so the physical census is ≥ these numbers, not
equal to them; assignment *safety* is still unproven. But
R3's status changes honestly: from "nothing, anywhere" to
"a measured floor from a real artifact" — and any future
artifact addressing higher indices raises the floor
monotonically.

## Evidence boundary

Driver negative is bounded to the two local trees (the same
trees as upstream hailort-drivers at their vintages).
Addressing floor is one artifact's usage, exact as counted;
the elision caveat is part of the result, not a footnote.
Next: 4.15 pair acquisition (model zoo) + cross-artifact
differential; per-context lane comparison; the firmware/
patent lane for the census's upper story remains open.
