# J-032 — The 80B-Class Target

**Slice:** J-032 (Part II — Models Bigger Than Memory), Project Aesir Janas clean-room road.
**Roadmap text:** "The largest sha-pinned MoE file the laptop can be made to hold a conversation with (the Janas headline class), attempted honestly: runs graded, walls recorded; if the file or the machine refuses, the refusal is the result, filed as NOT PROVEN with the blocker named."
**Executed:** 2026-10-31 ~12:30–12:4x EDT. **Closure shape: CLOSED-WITH-DEFERRED-LEG — verdict NOT PROVEN. The refusal is the result, exactly as the roadmap prescribes.** The one pin-verified 80B-class attempt on record (J-022's) was re-verified first-hand from its filed artefacts this slice (25/25 checks PASS, §3); a candidate survey of the J-011 matrix and the J-015 anatomy found no other sha-pinned 80B-class candidate and no smaller-quant Qwen3-Next pin on record (§2); and no new live leg ran this slice for the coordination reasons stated plainly in §6. No conversation with an 80B-class model is claimed, no wall is claimed, and no number below comes from a run that did not happen.
**Base:** branch `yrsa/janas-j032` from `yrsa/janas-j031` tip `a73587e903ab9c5778204498e08c64d73f4e7a4b` (ls-remote verified before branching). Origin/main `ba7ee09b6b4d09967b571f2f39714e9119dc3772` untouched by this slice.
**No Janas material was used or needed** — this slice stands entirely on Aesir's own J-022 attempt artefacts, the J-011/J-015 campaign records, and this tree's session code; the clean-room law was not engaged beyond that record. Hailo untouched/parked. No README touched. No Docker. Nothing deleted to free disk (/tmp was 100 % full at slice start, pre-existing; scratch and TMPDIR went to the workspace overlay under `~/workspace/.verify-tmp/j032`).

**Headline: the 80B class is refused at the door, and the door is the architecture, not the disk.** The pin-verified file — Qwen3-Next-80B-A3B Q4_K_M, 48,506,100,512 B, sha256 `f73551b55e3796526c37772c96227151fa11af328802b8f9865d635104e280fd` — is genuinely larger than purplelongship's total GPU+RAM (45,661 MiB ≈ 47.88 GB, recomputed §3), which is precisely the class this slice exists to attempt. Aesir's loader refused it in under a second (`GGUF is missing required tensor: blk.0.attn_q.weight`), and behind that refusal the streamed session in this tree still admits only the `olmoe` architecture — there is no `qwen3next` loader admission and no `qwen3next` forward (blocker **B2**, J-022 §5, unchanged). That forward is roaded to **J-123**. The size fact, stated honestly (§4): expert streaming exists precisely so a file larger than memory can still hold a conversation — the resident set stays small and routed experts stream — so **file size alone is not the fundamental bar once a forward exists; the missing forward is.** Until J-123 lands, the 80B-class conversation is **NOT PROVEN**, and §8 files the exact recipe for the live attempt the moment the forward exists.

---

## 1. The attempt, stated honestly

The attempt this slice grades is J-022's, executed on purplelongship on 2026-10-31 ~06:47 EDT and filed as `j022_qwen3next_attempt.txt` beside the J-022 doc (re-read verbatim this slice, §3):

- **Command:** the streamed-MoE vehicle (`test_olmoe_stream_v2`) against `/home/volmarr/j022/Qwen3-Next-80B-A3B-Instruct-Q4_K_M.gguf`, context 512, expert cache 536,870,912 B, two prompt ids (`510,1708`), gen 1; `CUDA_VISIBLE_DEVICES=` (GPU hidden — no GPU claim), `nice 10`, timeout 90.
- **Machine state at attempt (from the artefact):** MemAvailable 37,465 MB; GPU 1 MiB used / 6,144 MiB total; the 204 road's S-093 build was live — the attempt is header/loader work only and exited before any stepping, so contention touches nothing in the result.
- **Outcome:** `EXIT=1`, in under a second, before any stepping:

```
Unhandled exception caught during execution: GGUF is missing required tensor: blk.0.attn_q.weight
```

No token was generated, no wall was recorded beyond the sub-second refusal, and nothing was graded — there was nothing to grade. J-022 §5's reading stands and is re-verified in §3: block 0 of this file is an SSM block and carries no `attn_q`; the loader's dense-shaped tensor requirements refuse the hybrid layout, and the session's own by-name gate would refuse the architecture next anyway. **Both refusals are the engine working as designed — fail closed, nothing partial, nothing faked.**

This slice ran **no new attempt** (§6): re-running the identical binary against the identical file from this tree — whose session gate §3 re-verifies is unchanged (`olmoe` only, no `qwen3next` anywhere in the module) — could only reproduce the identical refusal, on a box this worker cannot reach and must not contend for. A reproduced refusal would add no evidence; the filed refusal already is the evidence.

## 2. Candidate survey — is there any other 80B-class road in?

Surveyed this slice: the J-011 model matrix (campaign `CENSUS.md` §J-011, Janas public docs only) and the J-015 anatomy (campaign `J015_MOE_ANATOMY.md` + its pins), checked for (a) any other sha-pinned MoE candidate in the 80B class, and (b) any smaller-quant Qwen3-Next pin already on record. Findings:

**The J-011 matrix, MoE rows at or near the class:**

| Arch (J-011) | Models named | In the 80B class? | Sha-pinned on this road? | Aesir reads it today? |
|---|---|---|---|---|
| `qwen3next` | Qwen3-Next-80B-A3B-Instruct, Qwen3-Coder-Next | **Yes — the headline class** | **Yes — one pin (§3)** | **No — blocker B2** |
| `nemotron_h_moe` | Nemotron-3.5-Bolt-74B-A9B (NVIDIA 24 GB GGUF) | Near (74B) | No pin taken on this road | No — no loader/forward; Janas's own docs place it on an unmerged branch; its gate is J-131's, not this slice's |
| `qwen4exp` | Qwen3.8-Flash-Next (177B, Q2_0 66.4 GB) | Above the class | No pin taken | No — experimental by its own naming; its gate is J-131's |
| `qwen35moe` | Qwen3.6-35B-A3B class | No (35B class) | No pin taken | No |
| `qwen3moe` | Qwen3-30B-A3B (+Coder-30B) | No (30B class) | No pin taken | No |
| `gemma4` MoE | 26B-A4B | No | No pin taken | No (dense Gemma-4 only) |

**The J-015 anatomy:** its pins are OLMoE Q4_K_M (`8c310f14…f3f`) and Granite-MoE Q4_K_M (`48e0edcd…b3`) — the two Part II witnesses, neither in the 80B class — plus its §7 `qwen2moe` Q2_K witness (5,890,164,032 B). J-015 §1 records the larger families explicitly as rejected-for-that-slice and deferred: "Phi-3.5-MoE, DeepSeek-V2-Lite, Qwen3-Next-80B — all far above the cap; larger MoE anatomies are J-022/J-032/J-123 territory." No other 80B-class pin was taken there.

**Smaller-quant Qwen3-Next: none on record.** No Q2_K / Q3_K / IQ-class Qwen3-Next file is sha-pinned anywhere in the campaign records surveyed, and J-022 §5 distinguishes the one pin that exists from the official Qwen repo's different Q4_K_M file (48,410,988,384 B, sha256 `d103b273…c061a`) — neither is a smaller quant. **And a smaller quant would not change the verdict anyway, stated plainly:** the refusal in §1 is architectural, not spatial. The loader refuses the hybrid tensor layout and the session admits only `olmoe` (§3, check 20–21) — a Q2_K `qwen3next` file would meet the identical two refusals at a smaller byte count. Quant choice decides whether the file fits the *streaming* budget once a forward exists; it cannot substitute for the forward. **Survey verdict: the J-022 pin is the only 80B-class candidate this road holds, and no candidate on record changes the §4 verdict.**

## 3. Re-verification — the refusal evidence, first-hand (25/25 PASS)

`j032_reverify.py` (filed beside this doc; output `j032_reverify_output.txt`, exit 0) re-parsed the filed artefacts and this tree — it copied no prose number without re-reading its source. What it established:

**The pin (from J-022 doc §5, re-read):** file `Qwen3-Next-80B-A3B-Instruct-Q4_K_M.gguf` from `unsloth/Qwen3-Next-80B-A3B-Instruct-GGUF` — **48,506,100,512 B**, sha256 **`f73551b55e3796526c37772c96227151fa11af328802b8f9865d635104e280fd`** (full value re-read and matched character-for-character), stated there to match the HuggingFace LFS pin exactly (size and sha both; the HF-API check itself was J-022's, not re-run this slice — no network leg was needed or claimed).

**The machine (recomputed):** RAM total 39,517 MiB + GPU 6,144 MiB = **45,661 MiB = 47.8790 GB** (script recomputation; J-022's "≈ 47.88 GB" confirmed). The file, 48.51 GB, exceeds that total by **0.63 GB**, and exceeds RAM alone by a wider margin. At attempt time MemAvailable was 37,465 MB (attempt artefact). The size condition of the roadmap text is therefore genuinely met by this file — this is not a too-small stand-in.

**The header (from J-022 doc §5, re-read):** architecture `qwen3next`; **48 blocks**; hidden 2048; **512 experts, top-10**; a shared expert (`expert_shared_feed_forward_length` 512); hybrid SSM (Gated DeltaNet) — `ssm.conv_kernel` 4, `ssm.state_size` 128, `ssm.group_count` 16, `ssm.time_step_rank` 32, `ssm.inner_size` 4096; **843 tensors**; a third of the blocks are not attention blocks at all.

**The refusal (from the attempt artefact, re-read verbatim):** `EXIT=1`; the exact exception text of §1; MemAvailable and GPU lines as in §1; `CUDA_VISIBLE_DEVICES=` in the recorded command environment.

**The gate today (from this tree, re-read):** `aesir_engine/core/moe_session.mojo` states "Only arch `olmoe` is admitted" and enforces `if arch != "olmoe":` with a refusal naming the module's scope; the string `qwen3next` does not occur in the module. **Blocker B2 is present in the current tree, not only in J-022's.**

## 4. Verdict — NOT PROVEN, blockers named exactly

**Verdict: NOT PROVEN.** Aesir has not held a conversation with any 80B-class MoE model, on any machine, at any quant. The attempt was made honestly, on a pin-verified file of the right class, and the machine/engine refused — and per the roadmap text, the refusal is the result.

**Blockers, named exactly (J-022's B2, split as filed there, both standing):**

- **B2a — no `qwen3next` loader admission.** The GGUF loading path's tensor-directory expectations are dense-shaped; the hybrid file's block 0 carries no `blk.0.attn_q.weight`, and admission fails there, in under a second, before any forward question is reached.
- **B2b — no `qwen3next` forward.** The architecture is a hybrid: Gated-DeltaNet SSM recurrence in a third of the blocks, attention in the rest, 512 routed experts at top-10, plus a shared expert firing every token. None of that exists in Aesir. The streamed session implements the `olmoe` block only. This is an architecture build, roaded to **J-123** (Part VIII — Qwen3-Next verification, which "binds J-022/J-032" in the roadmap's own words).

**The size nuance, stated honestly (binding on every later citation):** the file exceeding total GPU+RAM is the *point* of the class, not a second fundamental blocker. Part II's whole machinery — resident set held once, routed experts streamed from disk through the expert cache (J-018/J-019, proven on OLMoE in J-022/J-023 at a 4.21 GB file) — exists so that file size alone does not decide runnability; what decides it is resident-set size plus the streamed working set, and this file's resident anatomy (embeddings, attention/SSM state, routers, shared experts) is a J-123 measurement, not yet taken. So: **the forward is the fundamental bar; the size is the test the forward, once built, must pass by streaming.** Recording size as an equal blocker would misstate the road's own design, and recording the conversation as merely "size-blocked" would be wrong. Conversely, nothing here proves the streaming machinery *will* carry this file at a usable wall — its per-token demand at 512 experts × top-10 × 48 blocks is unmeasured, and no tok/s is claimed or implied (§7).

## 5. Reopen conditions

Any one of these reopens this slice's live leg; none is met today:

1. **The `qwen3next` forward lands via J-123** — loader admission plus a faithful hybrid forward (SSM/Gated-DeltaNet blocks, attention blocks, shared expert, 512-expert routing), graded per-arch there. This is the named road and the expected path.
2. **A larger-memory machine** enters the road's service — one whose RAM (+GPU) holds the file resident, *and* on which an admitted architecture exists. (Memory alone does not reopen: without B2 resolved, a bigger machine meets the same loader refusal. This condition only helps in combination with condition 1 or 3.)
3. **Another 80B-class architecture Aesir already reads** acquires a pin-verified file on this road — i.e. an arch with a working Aesir loader + forward whose 80B-class MoE file is sha-pinned the J-022 way. §2's survey records that none exists today: every other matrix MoE arch is likewise unread, and the dense lines Aesir does read have no 80B-class MoE file.

## 6. No new live leg ran this slice — stated plainly, with the timeline

- **Coordination:** the 204 road's **S-097 was dispatched ~12:12 EDT** (keeper dispatch record at this slice's start) and is live on purplelongship. Coordination law: yield — no heavy run, no contention, no stacking. An 80B attempt is header/loader work (as J-022's was), but it still requires the box, a build, and a guard this worker cannot supply (next point).
- **This worker has no device route to purplelongship** (the same posture recorded by the J-024/J-028/J-029/J-030/J-031 workers): it cannot verify on-box processes, cannot confirm the file still sits at `~/j022/` on the box, and cannot run a guarded attempt. An attempt it cannot guard or verify would be exactly the unmeasured claim this road forbids.
- **The VM cannot substitute:** MemAvailable measured this slice at ≈ 4,678 MB (`/proc/meminfo` at slice start) — below the 5,500 MB inference gate — and the VM holds neither the file nor a `qwen3next` path in any case. No VM inference was attempted.
- **And the decisive point (§1):** the tree this slice branched from re-verifies as `olmoe`-only (§3). A new attempt from it is a known refusal, not an experiment. The honest slice is the re-verified refusal, the survey, and the recipe — not theatre.

## 7. Honesty ledger

- **PROVEN:** the J-022 pin as filed (size + full sha256 re-read and matched, §3); the refusal artefact's contents (verbatim re-read); the machine-total arithmetic (recomputed, 45,661 MiB = 47.8790 GB; file exceeds it by 0.63 GB); the session's `olmoe`-only gate in this tree (code re-read); the survey's negative result as scoped (§2 — the J-011 matrix and J-015 records contain no other sha-pinned 80B-class candidate and no smaller-quant Qwen3-Next pin).
- **MEASURED:** every J-022 figure re-cited (file size, header facts, attempt-time MemAvailable/GPU) — J-022's measurements, re-verified against its filed artefacts this slice, keeping their original class; the VM's MemAvailable this slice.
- **MEASURED-INDICATIVE:** nothing new — no wall was measured this slice; the sub-second refusal is J-022's record, not a benchmark.
- **SIMULATED:** nothing.
- **NOT PROVEN:** any 80B-class conversation, generation, wall, or tok/s on any hardware; that expert streaming carries this file's demand at any wall (§4's nuance cuts both ways); this file's resident-set size and per-token streamed demand (a J-123 anatomy measurement, not taken); `qwen3next` faithfulness under any grading (no forward exists to grade); the §2 near-class candidates (Nemotron 74B, Qwen3.8-Flash-Next 177B) in every respect — unpinned, unread, and gated elsewhere (J-131).

## 8. The live attempt, once the forward exists — exact recipe (for J-123's worker / the J-034 gate)

In a verified clean gap on purplelongship (204 heartbeat checked **and** on-box guard: no 204 worker processes at leg start, per the J-023 guard discipline; the J-023/J-030 pattern throughout):

1. **Re-pin before running.** Confirm the file on-box still hashes to `f73551b55e3796526c37772c96227151fa11af328802b8f9865d635104e280fd` and sizes to 48,506,100,512 B (trust only disk; if the store moved, re-fetch from `unsloth/Qwen3-Next-80B-A3B-Instruct-GGUF` and re-verify size + sha against the HF LFS pin before anything runs). Record the J-123 anatomy's resident-set and per-token demand figures first — they set the cache budget honestly.
2. **Build** from the then-current Janas branch tip (which by then carries J-123's admission + forward) with the proven J-022 recipe (C shims first, then `pixi run mojo build` + shim link flags) — the streamed-session vehicle, or its J-123 successor.
3. **Configuration:** context 512; expert-cache budget 536,870,912 B (the J-022/J-030 standard) as the headline leg, with a second leg at the largest budget the machine state honestly allows if the first completes; `CUDA_VISIBLE_DEVICES=` for the CPU-line leg (a GPU-assisted leg, if J-031's deferred work has landed by then, is a separate leg, logged with `nvidia-smi` at start/end — never silently mixed).
4. **Prompt and grading — raw-oracle discipline, ids first:** run the road's standard prose prompt (the 67-id lighthouse set if the tokenizer admits it for this arch; otherwise a prompt tokenized by the model's own stack, with the id list filed). **First gate: token identity / self-consistency** across the two cache legs (ids must not change with cache budget — J-022's bisection precedent; any divergence is a defect to bisect, not a number to file). **Second gate: faithfulness** — teacher-forcing rank + logit gap against the ggml CPU comparator on the **raw prompt** (CPU vs CPU comparator; near-tie band rank ≤ 2 with sub-logit gap = faithful; comparator artifacts — template rendering, BOS, backend mismatch, prompt-boundary step-0 — are a verdict class, checked before the engine is suspected). **Never `llama-cli --single-turn`** as an oracle.
5. **Record:** full run logs + machine state per leg (loadavg, Tctl, MemAvailable, GPU) at start/end; walls as MEASURED-INDICATIVE single runs; cache/stream counters in the J-016 vocabulary; the decoded output verbatim. A refusal, a crash, or an incoherent grade are all fileable results — filed as NOT PROVEN with the blocker named, per this slice's own shape.
6. **File results beside this doc**, state which of §5's reopen conditions was met, and re-cite §4's nuance: confirmed (streaming carried a bigger-than-memory file) or refined by measurement.

## 9. For the J-034 gate — re-cite (binding)

The Part II gate (J-034) must re-cite this deferral, in these terms: **J-022's bigger-than-RAM leg and J-032's 80B-class target stand NOT PROVEN under blocker B2 (B2a loader admission, B2b forward — both `qwen3next`), roaded to J-123; the file is pin-verified (48,506,100,512 B, sha256 `f73551b5…80fd`) and exceeds purplelongship's total GPU+RAM (45,661 MiB ≈ 47.88 GB); size is the test, not the fundamental bar — the forward is (§4).** The §8 recipe is the gate's (or J-123's) execution road for the leg. This joins the gate's existing re-cite list: J-024's live confirmation + dropping agreement legs, J-026's live two-session leg, J-028's live mid-run pressure leg, J-030's dedicated fresh CPU-line leg, and J-031's live GPU leg.

## 10. Defects and gaps found

- **No defect found** in the J-022 attempt record, the J-011/J-015 records, or the session code: the re-verification's 25 checks all PASS, the arithmetic closes (0.63 GB over the recomputed total), and the `olmoe`-only gate behaves exactly as designed — it refuses an unimplemented architecture by name rather than running it dense-shaped. Blocker B2 is an **absence** (an unbuilt architecture), recorded as J-123's build — not misbehaving code, and not a bug this slice could fix in scope: a hybrid SSM/MoE forward is Part VIII's slice, and attempting it inside a keeper tick on an unreachable, occupied box would be the inflation this road's honesty classes exist to prevent.
- **The standing gap this slice closes:** J-032's roadmap question — "the largest sha-pinned MoE file the laptop can be made to hold a conversation with" — now has its honest, evidence-backed answer filed (none yet; the refusal, the blockers, the survey, and the recipe), instead of resting on J-022's in-progress record alone.

## 11. Artefacts

Filed beside this doc in `docs/janas/`: this document; `j032_reverify.py` (the re-verification of §3); `j032_reverify_output.txt` (its filed output, 25/25 PASS, exit 0). Campaign copies of all three live in `~/workspace/model-tests/janas/`, sha-identical. The evidence this slice stands on (`J022_FIRST_BIGGER_THAN_RAM.md`, `j022_qwen3next_attempt.txt`, the J-011 census and J-015 anatomy) already stands filed under its own slices.
