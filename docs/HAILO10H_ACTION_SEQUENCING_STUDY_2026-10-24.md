# Action sequencing for a real program — Track R item R4 study (2026-10-24)

Roadmap Campaign 4 iteration, slice 4.8 (AES-NUM-008), Track R.
**Research only — no emitter, no bytes, no physical run, no
invented sequence.** Question, left open by AES-NUM-003 layer 6
and AES-NUM-001 group B: for a real program on this target, is
there a *sourced* minimal-program action sequence — which
context-switch actions, in which order, with which counts and
completion addresses?

**Verdict: PARTIALLY ESTABLISHED.** The *ordering discipline*
is established at source level: the pinned configure path
(`ResourcesManagerBuilder` + `ActionListBufferBuilder`) takes a
context's action list and transforms it by deterministic,
fully-sourced rules (§2–§4), and the context *build* order at
configure time is likewise sourced (§5). But a *minimal
authorable sequence* is **NOT PROVEN**: the base action list
itself — the LCU enables, CCW writes, typed writes and triggers
a program consists of — is parsed out of the HEF
(`hef/core_op_metadata.cpp` @pin, `ContextMetadata::get_actions`),
i.e. it is DFC-authored content, and its counts and completion
addresses are HEF-carried values, not derivable ones (§6–§7).
Aesir has no HEF, no CCW layout (R1 NOT PROVEN) and no placement
values (R3 NOT PROVEN), so it cannot author the base list this
discipline orders. AES-NUM-003 layer 6 therefore stays
**INCOMPLETE**, with its missing fact narrowed (§8); the 4.4
gate re-run on layer 6 only **passes** (§8). The F1 result-path
qualification question does not move: research cannot qualify a
path, so layer 7 is unchanged.

## 1. Search bounds (what was actually searched)

1. **Pinned public HailoRT** `d503417f2a0db186a838390fb08690c4ea0f415e`
   (v5.3.0, MIT, interface facts only) — read this slice, at
   the pin, via the GitHub connector (study copies kept
   outside the Git tree):
   - `hailort/libhailort/src/core_op/resource_manager/resource_manager_builder.cpp`
     (1,422 lines; sha256 `035af3cc…`) — the configure-path
     sequencing owner: every context recipe in §2–§5 is here.
   - `…/resource_manager.cpp` (sha256 `35228993…` — matches
     the hash recorded in `HAILO10H_PUBLIC_CONTEXT_ACTIONS.md`),
     `…/action_list_buffer_builder/action_list_buffer_builder.{hpp,cpp}`
     (sha256 `531e2b1f…` / `c444c6c2…` — both match the same
     record): the builder appends serialized actions in caller
     order and starts a new control only on a new context or
     when the current control has no room — chunking is
     size-driven, never semantic.
   - `common/include/context_switch_defs.h` and
     `common/include/control_protocol.h` read at the pin;
     sha256 `fa8fa9f9…` / `a10865db…`, both matching the
     recorded study hashes — pin integrity cross-checked, not
     assumed.
   - Code search at the pin for `get_actions`: its definition
     is `ContextMetadata::get_actions` in
     `hailort/libhailort/src/hef/core_op_metadata.cpp` — the
     base lists are HEF-parsed (§6).
2. **This repo's own evidence** — AES-PROG-001 (the hRPC
   lifecycle sequence 20/2+payload/4/10/11/12/5/3/21 is already
   ESTABLISHED there and is a *different namespace* from the
   context actions below; this study does not re-grade it),
   AES-NUM-001 group B, AES-NUM-003 layer 6, the 2026-10-19
   public-context-actions study (which recorded that resource
   management passes these controls through the local VDMA
   device path and that the pinned server's dispatcher provides
   configure/activate/run lifecycles into the local VDevice
   API — the chain by which this builder is the receiver's
   configure path at source level).
3. **Open web** — not needed beyond the pin for the ordering
   rules (they are stated in the pinned code and its comments);
   no web source states a minimal authorable sequence, and
   none is claimed.

Bounded-search caveat, as in AES-NUM-005/006/007: graded
results over the sources named. Everything below is
**source-level** (PUBLIC INTERFACE FACT in the roadmap's tags):
the builder's behaviour is what the pinned code does, not a
physical observation on Mimir, and **build order is not
device execution order** (§5).

## 2. R4a — the transformation discipline: ESTABLISHED (source level)

Each context recipe in `resource_manager_builder.cpp` @pin
starts from `context_metadata.get_actions()` (the HEF-carried
list, §6) and applies the same transformations, in this order
(dynamic contexts, `fill_context_recipes_for_multi_context`;
the preliminary recipe applies the same steps minus the
edge/end-of-context steps unless `preliminary_run_asap`):

1. **Fetch insertion** (`add_fetch_config_actions`): walking
   the list in order, every `WriteDataCcw` action is replaced
   in place by a fetch action for its config stream —
   `AddCcwBurstAction` carrying that write's own
   `total_ccw_burst()` in the pre-fetch flow used by both
   recipes (`support_pre_fetch = true`); in the non-pre-fetch
   flow, `FetchCfgChannelDescriptorsAction` carrying the
   copied config buffer's descriptor count. All other actions
   pass through in order. (The function's comment says a fetch
   is added "at the end of each consecutive group of
   WriteDataCcwAction"; the code inserts one per write action,
   in place — the code governs, the discrepancy is recorded,
   not smoothed over.)
2. **Edge-layer activation insertion**
   (`handle_edge_layer_activation_actions`, contexts with edge
   layers): at the single consecutive group of
   `TriggerNewDataFromDataInput` actions (the code CHECKs
   there is exactly one such group), the pre-allow-input
   configuration is inserted *before* the group —
   edge-layer activation in the order **outputs first, then
   DDR inputs, then inputs** ("in order to insure that input
   data can enter the chip only after all other elements are
   configured"), then (multi-context) `ChangeVdmaToStreamMapping`
   per boundary stream, then DDR pair-info + start-buffering,
   then boundary-input resume — and a `StartBurstCreditsTask`
   action is appended *after* the group if the context has a
   boundary input. The trigger actions themselves stay in
   place and in order.
3. **Config-channel wrap** (`add_config_channel_activation_actions`):
   one `ActivateConfigChannel` per config buffer is prepended
   at the head of the context and one `DeactivateConfigChannel`
   per config buffer appended at the tail — "Push activate
   config channels in the beginning of the context, and
   deactivation on end of context."
4. **Repeated-action compression** (`handle_repeated_actions`):
   consecutive mergeable groups gain a repeated-action header
   (the `repeated_action_header_t` documented in
   `context_switch_defs.h` @pin); order is otherwise preserved.
5. **End-of-context actions (dynamic, multi-context)**:
   `DisableDataChannels` from the HEF is replaced in place by
   per-edge-layer deactivate actions (validate first, under
   extended firmware checks), then boundary-input
   `PauseVdmaChannel` actions are appended last — the code's
   own comment: "End of context actions - these must be last
   in their respective context." A single-context network
   instead appends `WaitForNetworkGroupChange`; a last context
   with KV cache enabled appends `WaitForCacheUpdated`.

The **activation context** is built by its own recipe: a
`ResetBurstCreditsTask` first, then one open-boundary-channel
action per boundary edge layer (input or output by direction).
The **batch-switch context**: one `SwitchLcuBatch` derived from
*each* LCU-enable action found in the preliminary context
(same packed id and network; kernel-done count per §4), then
close internal channels, reset DDR buffering, re-open internal
channels, DDR pair info, change-boundary-input-batch per
activation boundary input, and a final `StartBurstCreditsTask`.

Serialization preserves all of this exactly:
`write_action_list` serializes each action in list order into
the builder, whose `build_context` appends in caller order.

## 3. What the discipline does not do

The builder never invents, reorders, or drops a base action:
outside the five insertions above, the HEF list's order is the
program's order. There is no sorting, no dependency analysis,
and no minimality notion in the pinned code — "minimal
program" is not a concept this layer defines. Any sequence
Aesir authored would have to supply the base list itself; the
discipline would then order its *insertions*, not validate
its *contents*.

## 4. R4c/R4d — counts and completion addresses

**Counts — ESTABLISHED as functions, NOT PROVEN as values.**
Every count in the transformed sequence is either a literal
in the code or a value carried by the base list / resources:

| Count | Source @pin | Grade |
|---|---|---|
| CCW bursts per fetch insertion | the `WriteDataCcw` action's own `total_ccw_burst()` (HEF-carried) | function **IN**; the value for any Aesir program **NOT PROVEN** |
| Descriptor count (non-pre-fetch fetch) | `CopiedConfigBuffer::program_descriptors()` — derived from the config buffer's contents | function **IN**; value **NOT PROVEN** |
| Config-channel activate/deactivate counts | exactly the context's config-buffer count (one each, head/tail) | **IN** (a sourced function of the resource set, whose size is itself placement/CCW-dependent) |
| Batch-switch kernel-done count | default-enable source action → the literal `ENABLE_LCU_DEFAULT_KERNEL_COUNT` (2); non-default/switch source → its own `kernel_done_count` field (HEF-carried) | literal **IN**; HEF-carried value **NOT PROVEN** |

**Completion addresses — the 4.7 ancillary lands, narrowly.**
`context_switch_defs.h` @pin defines the default LCU-enable
record's completion defaults literally:
`ENABLE_LCU_DEFAULT_KERNEL_ADDRESS (1)` and
`ENABLE_LCU_DEFAULT_KERNEL_COUNT (2)`, and the header comment
on the default record states its kernel-done address/count
"have default values" — i.e. a default-enable action carries
*no* address field and the defaults above are the completion
terms. The non-default record carries `kernel_done_address`
u16 + `kernel_done_count` u32 *in the action*. **No searched
source establishes any non-default address value as safe**,
and the address space itself remains unknown (AES-NUM-001
group B, unchanged) — so for authoring, completion addresses
beyond the default literal are **NOT PROVEN**, exactly as
ID 35's address values remain OUT.

## 5. R4b — context build order at configure time: ESTABLISHED (source level)

`ResourcesManagerBuilder::build` @pin constructs contexts in
this order: **activation, batch-switching, preliminary, then
dynamic contexts in HEF index order**, then `configure()`.
Recorded as a *build* order only: no searched source states
the firmware's context *execution* order, and reading build
order as execution order would be an inference this study
does not make. **Device execution order: NOT PROVEN.**

## 6. R4e — a minimal authorable sequence: NOT PROVEN

The base list the discipline orders is
`ContextMetadata::get_actions()` — parsed in
`hef/core_op_metadata.cpp` from the HEF the configure call
receives. Its contents (which LCU enables with which packed
ids, which CCW writes with which burst counts, which typed
writes at which addresses, which triggers) are DFC's
generation choices. The Do Not Infer entry governs directly:
"HailoRT parsing a HEF field does not imply Aesir knows how
DFC generated the corresponding CCW payload." Combined with
R1 (CCW words NOT PROVEN — a `WriteDataCcw` action's payload
is exactly that unknown) and R3 (no safe packed-id/placement
values), there is no sourced way to state the base list for
the identity copy — not even a one-LCU, one-write skeleton,
because the skeleton's every field is one of those unknowns.
Inventing a plausible-looking skeleton is the failure this
campaign exists to refuse.

## 7. F1 — result-path qualification: UNCHANGED

AES-NUM-006 §4 described the readback path at source level and
recorded it unqualified in Aesir. This slice is research; it
adds no host qualification and no physical exercise, so the
path's status does not move and AES-NUM-003 layer 7 is not
re-graded. The qualification question stays open as future
host-side work, exactly as F1 left it.

## 8. Re-grade and the 4.4 gate, changed layer only

Addendum to AES-NUM-003 (also appended to that document):

- **Layer 6 (dynamic program/LCU actions):** its missing fact
  narrows. Was: "a sourced minimal-program action sequence
  (from the pinned receiver/configure path)" unestablished in
  full. Now: the **ordering discipline is ESTABLISHED at
  source level** (§2, §5) and the **counts/completion terms
  are established as functions and one literal** (§4); the
  remaining unknown is the **base action list itself and its
  carried values** — DFC-authored, blocked jointly by R1 and
  R3 (§6). Layer 6 stays **INCOMPLETE**: a layer that requires
  "which actions this operation requires" does not clear on
  an ordering discipline for a list nobody can yet write.
- **Gate re-run (4.4 terms, layer 6 only):** every new
  statement carries a pin-cited source or an explicit NOT
  PROVEN grade. No Do Not Infer entry is violated: an hRPC
  action id is **not** read as a context action (the two
  namespaces are kept separate, §1); build order is **not**
  read as execution order (§5); HEF parsing is **not** read
  as knowledge of DFC generation (§6 — the entry is quoted
  and enforced); source-level establishment is **not** read
  as Aesir qualification or physical proof (§1). **PASS on
  the changed layer.**

Unchanged and still blocking: layers 2/3/5 and layer 8's
device half (R1, R3 NOT PROVEN; R5 open). **Campaign 4 EXIT
still NOT MET; operation UNQUALIFIED; Campaign 5 NOT
contracted.**

## 9. R4 disposition and what remains

- **R4: PARTIALLY ESTABLISHED** — ordering discipline and
  build order ESTABLISHED at source level; counts/completion
  established as functions plus the default literal; a
  minimal authorable sequence and any non-default completion
  address **NOT PROVEN**. R4 closes this study pass under the
  4.4 gate's terms (each sub-question closed on IN-grade
  evidence or recorded NOT PROVEN).
- Remaining Track R order: **R5 — partial-state teardown**
  (slice 4.9), the last item; it blocks layer 8's device half.
  After R5, Campaign 4's iteration stands at: R1 NOT PROVEN,
  R2 ESTABLISHED, R3 NOT PROVEN, R4 PARTIAL, R5 pending — the
  campaign's exit will still turn on R1/R3-class evidence
  (a public CCW layout and placement census), not on further
  sequencing work.

## 10. Audit

Research only. No code, no emitter, no bytes constructed, no
physical child, no device contact. Sources: pinned HailoRT
files read at `d503417f…` via the GitHub connector, with
sha256 cross-checks against this repo's recorded study hashes
where they exist (§1); repo evidence as cited.
