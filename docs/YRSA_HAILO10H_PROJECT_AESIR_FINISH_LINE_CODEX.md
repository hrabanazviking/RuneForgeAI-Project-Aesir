# THE YRSA CODEX
## Hailo-10H Native Execution for Project Aesir
### Architecture, runtime, compiler, transport, LLM contract, evidence ledger, and finish-line roadmap

**Prepared for:** Yrsa and Project Aesir  
**Owner:** Volmarr Wyrd  
**Snapshot date:** 2026-10-24  
**Primary project:** `hrabanazviking/RuneForgeAI-Project-Aesir`  
**Primary hardware target:** Hailo-10H attached to Raspberry Pi 5  
**Installed physical stack in Aesir evidence:** kernel `6.12.112-v8-16k-hailo+`, Hailo driver/runtime family 5.3.0  
**Current public Hailo software generation used for delta research:** HailoRT / DFC 5.4.x  
**Project target:** ordinary, unmodified source models loaded by Aesir and internally translated in Mojo, with LLM inference executed on Hailo-10H and no vendor-precompiled model prerequisite.

---

# How to use this book

This is not a marketing guide, a generic NPU introduction, or a tutorial for using precompiled Hailo models. It is a technical handoff intended to let an advanced AI coding agent understand what Project Aesir has already established, what remains unknown, which external facts are trustworthy, which experiments are still missing, and how to continue without silently changing Volmarr's target.

The intended reader is Yrsa. Read the **Evidence Language**, **Non-negotiable Project Scope**, **Current Frontier**, and **Do Not Infer X From Y** chapters before proposing code. Those chapters are the guardrails that prevent months of careful work from being collapsed into a false claim.

The book deliberately distinguishes:

- facts physically observed on Volmarr's Hailo-10H;
- facts verified only in host-side Mojo tests;
- public Hailo interface facts;
- architectural clues from patents;
- findings from an independent experimental Hailo-10H LLM compiler;
- hypotheses that still require proof;
- unknowns where guessing would be dangerous or scientifically useless.

The central engineering challenge is not merely loading an LLM. Aesir already has a working HailoRT route for a compatible compiled model. The hard target is:

```text
ordinary GGUF / Safetensors model
        |
        v
Aesir-owned parser and semantic compiler
        |
        v
Aesir-owned transformer IR
        |
        v
Aesir-owned Hailo numerical lowering
        |
        v
Aesir-owned packing / placement / program generation
        |
        v
Aesir-owned Hailo transport and control
        |
        v
Hailo-10H executes the LLM
        |
        v
Aesir returns tokens
```

No step marked unknown may be replaced with an invented opcode, guessed register, made-up descriptor formula, or metadata field that merely sounds plausible.

---

# Evidence language

Use these tags in future notes, commits, tasks, and reasoning.

| Tag | Meaning |
|---|---|
| **PHYSICALLY VERIFIED** | Observed on Volmarr's actual Hailo-10H under a recorded hardware/software profile. |
| **HOST VERIFIED** | Native Mojo/C/C++ host behavior is tested, but no physical NPU effect is established. |
| **PUBLIC INTERFACE FACT** | Present in Hailo's public MIT/GPL source or official documentation. It describes an interface, not necessarily hidden silicon semantics. |
| **OFFICIAL PRODUCT FACT** | Stated in Hailo's official product documentation. |
| **EXTERNAL EXPERIMENTAL** | Measured or reverse-documented by another open project. Valuable evidence, but not automatically Aesir truth. |
| **PATENT ARCHITECTURAL LEAD** | Hailo patent material that can reveal design concepts but must not be treated as an H10H programming manual. |
| **INFERENCE** | A reasoned interpretation supported by facts but not directly measured. |
| **UNKNOWN** | Not established. Do not fill with intuition. |

A useful rule for Yrsa:

> If a statement would allow a new physical write, new program submission, new descriptor-use formula, new numerical encoding, or a new claim of model execution, require PHYSICALLY VERIFIED evidence or a separately contracted experiment.

---

# Non-negotiable Project Aesir scope

The owner scope recorded on 2026-10-20 is the controlling mission:

1. **Broad model support is the target.** Missing formats, architectures, operators, quantization schemes, or backend encodings are implementation work, not permanent exclusions.
2. Users should provide **ordinary, unmodified source-model files** of a size compatible with Hailo-10H.
3. Users must not be required to run Hailo's Dataflow Compiler, use another compiler host, or obtain a vendor-precompiled HEF.
4. Aesir owns source loading, representation conversion, model semantics, operation lowering, device program/configuration generation, orchestration, and hardware execution.
5. The implementation language for the native route is Mojo, with narrow system seams only where necessary.
6. CPU, CUDA, cloud, or proxy LLM inference does not count as completion of the Hailo path.
7. HailoRT, DFC, other open projects, patents, and public schemas may be studied as evidence or isolated oracles, but external implementations must not simply be copied or translated into Aesir.
8. Current capability must always be reported honestly. A stated goal is not a capability.
9. HEF knowledge is used to understand what functional content must be replaced. Aesir's final source-model route does not require the user to create or supply HEFs.

This scope is stricter than a normal Hailo integration project. It is effectively an independent model compiler and runtime project targeted at Hailo-10H.

---

# Executive status: where Aesir actually stands

## Two Hailo routes exist

### Route A: HailoRT plus a compatible compiled model

**Status: PHYSICALLY VERIFIED.**

Aesir has a direct Hailo-10H inference path in which Mojo dispatches through `hailo_commands.mojo` and `Hailo10HSession`, while a narrow native bridge owns an in-process HailoRT GenAI session. A Qwen2.5-1.5B-Instruct compiled artifact was physically loaded and run on the Hailo-10H. Recorded acceptance included:

- real Hailo-10H device identity;
- HailoRT / firmware 5.3.0 generation;
- approximately 2.46 GB compiled model artifact;
- a simple arithmetic prompt returning `5.`;
- persistent conversation context;
- context-overflow refusal without history mutation;
- clear/reset behavior;
- post-reset generation;
- lifecycle cleanup;
- 12/12 boundary/lifecycle checks in the recorded slice.

This proves that Project Aesir can orchestrate real Hailo-10H LLM inference through HailoRT.

It does **not** satisfy the owner's native source-model target because the model is already in a Hailo-compatible compiled form.

### Route B: Aesir-owned source model to Hailo-10H

**Status: ACTIVE, NOT END-TO-END.**

This is the real target. It contains two large bodies of work that are both quite advanced:

```text
SOURCE COMPILER SIDE                     DEVICE SIDE
--------------------                     -----------
GGUF / Safetensors                       driver discovery
       |                                 device properties
       v                                 descriptor lists
sealed source ownership                   channel allocation
       |                                 connections
       v                                 USERPTR mapping
model metadata and tensors                grouped storage
       |                                 IRQ completion model
       v                                 hRPC framing
transformer semantics                     typed device RPC
       |                                 deadlines / cleanup
       v                                 sealed program buffers
mathematical graph                        physical buffer mapping
       |                                       |
       +------------------ GAP ----------------+
                         |
                         v
            numerical H10H program
                         |
                         v
                   execution/result
```

The missing bridge is not vague. The repeated repository wording is consistent:

- actual numerical device configuration;
- precision choice and device representation;
- tensor packing;
- physical resource placement;
- exact CCW / context / LCU programming values;
- original program delivery and activation;
- result retrieval;
- full failure cleanup;
- broad architecture/operator coverage.

Aesir has reached the edge of these problems but has not yet crossed them with a native source model.

---

# Current frontier as of 2026-10-24

The newest host-qualified control work implements a grouped device lifecycle around typed create, identify, and destroy operations. The latest published next contract calls for **one bounded physical grouped lifecycle** on the real device after host qualification.

The recent progression is:

| Capability | State | What it actually proves |
|---|---|---|
| AES-CONTROL-009 sealed two-part driver mappings | verified, including physical children | Real mapping compatibility and ownership, not model DMA or compute. |
| AES-CONTROL-010 prepare/cancel wire codecs | host verified | Exact host bytes for those control messages. |
| AES-CONTROL-011 observed grouped progress | host verified | Launch-return accounting, IRQ completion correlation, total-deadline logic. |
| AES-CONTROL-012 same-file session ownership | host verified | Buffer ownership tied to the same session file that owns lists/channels. |
| AES-CONTROL-013 same-file physical session maps | physically verified | Six real mappings, device/session cleanup. No DMA packet or numerical request. |
| AES-CONTROL-014 grouped control frames | host verified | One D2H plus one grouped H2D transaction model, counts/deadlines/poisoning, still mocked. |
| AES-CONTROL-015 typed grouped create/identify/destroy | host verified | Full lifecycle policy and typed replies, still no physical grouped DMA. |
| Next physical grouped lifecycle contract | contracted, not yet accepted in the snapshot used here | Exactly one real create/identify/destroy grouped lifecycle under bounded deadlines. |

The most important sentence for Yrsa:

> Aesir can now create the host-side ownership and control machinery needed to talk safely to the device, but it still lacks a proven Aesir-generated numerical program that the Hailo-10H accepts and executes.

---

# Do not infer X from Y

This table should be treated as law until stronger evidence supersedes an entry.

| Observed Y | You may NOT infer X |
|---|---|
| USERPTR map succeeds | The bytes are coherent for device DMA, descriptors are correct, or the program is executable. |
| Driver returns a positive launch/count value | A universal descriptor-count formula or device capacity. |
| An IRQ arrives | Correct model semantics, correct returned data, or program completion unless the assigned direction/channel and protocol state correlate exactly. |
| Device file closes successfully | Remote logical destruction, all DMA stopped under every failure path, or hardware idle. |
| hRPC action ID exists | It is an arithmetic opcode or LCU instruction. |
| Sequencer record contains an `active_l2` bitmap | The physical meaning of each bit or the legal H10H resource count. |
| HEF metadata names a shape or layout | The numerical hardware instruction encoding is known. |
| HailoRT can parse a HEF field | Aesir knows how DFC generated the corresponding CCW/configuration payload. |
| A model's weights fit in LPDDR | Its contexts can be placed, its operators are supported, or its temporary working set fits. |
| A source model parses successfully | It can execute on the NPU. |
| A mathematical graph is correct | Numerical quantization, packing, placement, or scheduling is correct. |
| A DFC emulator reports good cosine | Real silicon will behave identically. An independent project found a multi-head softmax emulation defect. |
| A DFC emulator reports bad cosine | Real silicon is necessarily bad. The same external project found cases where emulator behavior was worse than hardware. |
| Outer XXH3 checksum validates | LCU microcode CRC, hardware safety checks, target compatibility, or arithmetic correctness. |
| Runtime device enum value is `6` | HEF/program architecture enum is also `6`. The namespaces differ. |
| A compatible family mapping includes Hailo-10H | Arbitrary HAILO1XH programs are physically valid on the exact device. |
| A patent shows a field, block, or illustrative opcode | It is the exact Hailo-10H register/bit encoding. |
| A community compiler works with DFC | The community project is an independent Hailo compiler or satisfies Aesir's no-DFC target. |

---

# Part I - Hailo-10H fundamentals

## Official product facts

Current Hailo product documentation describes Hailo-10H as a second-generation AI accelerator designed for both vision and generative AI. The stable official facts useful to Aesir are:

- 40 TOPS at INT4 and 20 TOPS at INT8, quoted peak vendor figures;
- typical power around 2.5 W;
- LPDDR4/LPDDR4X support;
- structure-driven dataflow neural-core architecture;
- host support centered on x86 and ARM;
- Linux, Windows, and Android software support;
- deployment as a co-processor, commonly over PCIe;
- a software split between model-build tooling and runtime tooling;
- HailoRT as the runtime API layer;
- a Dataflow Compiler that maps source frameworks to target-specific executable content;
- explicit GenAI support in the current software ecosystem.

The product brief intentionally does not document the numerical instruction encoding, exact compute-resource map, register-level NN programming interface, or compiler placement algorithm. Those remain the hard parts of Aesir's native effort.

## Current software generation

As of this book's date:

- Hailo's public `hailort` master targets Hailo-10 and Hailo-15 families.
- Hailo's Model Zoo master advertises HailoRT and Dataflow Compiler 5.4.0 generation.
- Aesir's physically qualified Pi/Hailo evidence is primarily pinned to 5.3.0.
- Aesir has already performed a 5.3.0 to 5.4.0 public interface delta study.

Do not casually update Aesir's physical assumptions from 5.3.0 to 5.4.0. The right rule is:

```text
physical behavior -> trust the recorded installed 5.3.0 profile
public schema research -> track both 5.3.0 and 5.4.0
new physical test -> first record exact live versions, hashes, and identities
```

This is especially important because direct firmware-control layouts changed in public 5.4 source even though several HEF and hRPC structures remained stable.

---

# Structure-driven dataflow: the mental model

Hailo's public language and older architectural disclosures describe a structure-driven dataflow architecture rather than a conventional GPU-style stream of general instructions.

A useful conceptual model is:

```text
neural network graph
      |
      v
compiler decomposes layers into resource needs
      |
      +--> compute resources
      +--> local memory resources
      +--> control / layer-controller resources
      +--> data movement routes
      |
      v
resources are spatially placed and scheduled
      |
      v
small control programs coordinate layer execution
```

Hailo patent material describes hierarchical, self-contained compute units with tightly coupled local memory and control resources aggregated at higher levels. Hailo community explanations use three broad categories:

- **compute** resources perform numerical operations;
- **memory** resources retain weights, activations, and intermediate values;
- **control** resources, including Layer Controller Units (LCUs), schedule and coordinate data flow.

This matters because Aesir should not think of the missing backend as simply generating a list of matrix opcodes. The hidden compiler problem includes:

1. numerical operation selection;
2. resource allocation;
3. local-memory placement;
4. data-route configuration;
5. layer scheduling;
6. small control programs / sequencer state;
7. integrity/safety fields;
8. context switching;
9. host-visible stream and cache metadata.

Aesir's existing IR and matrix schedules solve only the model-side description and some host-side planning. The silicon still needs its own exact configuration language.

---

# What the patents can and cannot tell us

Several Hailo patents are useful architecture maps.

## Neural processing element with compute and local memory

Hailo's processing-element patent describes a hierarchical architecture built from computational units that combine compute with appropriately proportioned local memory. This supports the general idea that placement must respect a spatial hierarchy rather than treating memory as one flat SRAM.

**Use it for:** architectural concepts, terminology, likely resource relationships.  
**Do not use it for:** exact H10H register offsets, resource counts, instruction values, or placement coordinates.

## LCU instruction-addressing safety

Hailo's LCU safety patent describes mechanisms in which the compiler supplies reference values associated with a microcode program, including:

- expected program length;
- opcode-count checks;
- a reference opcode at a selected count;
- CRC/checksum style validation over executed opcodes;
- end-of-program detection.

This strongly supports the idea that the chip executes compiler-generated microcode and performs integrity checks on that control flow.

It does **not** reveal a verified H10H opcode format or CRC polynomial.

Aesir should therefore expect that a fully valid native context may need more than syntactically valid configuration bytes. It may also require internally consistent program length and safety fields.

## Configurable memory windows

Another Hailo patent describes configurable memory/compute windows and non-contiguous access, with a distinction between static configuration and dynamic instruction signals. That is consistent with Aesir's expectation that tensor placement requires both quasi-static resource setup and dynamic control.

Again, diagram labels are not addresses.

---

# Memory architecture and why GenAI changes the problem

Hailo-10H adds external/local LPDDR support for larger models. Public Hailo discussion states that models execute from the accelerator's local memory rather than treating host RAM over PCIe as a live weight store. This is a crucial design constraint for Aesir.

For LLMs, think about memory in at least five categories:

1. **Model weights** - mostly static after loading.
2. **Layer working buffers** - temporary activations, normalization products, Q/K/V projections, MLP intermediates.
3. **KV cache** - persistent across decoding steps and updated token by token.
4. **Program/configuration data** - contexts, CCWs, sequencer data, metadata.
5. **Host transport buffers** - prompt embeddings/input records, generated outputs, control RPC, program upload staging.

Aesir's compiler will eventually need separate accounting for all five. A simplistic `model_file_size < device_memory` test is not a fit test.

For transformer inference, decoding performance is often constrained by movement of weights and KV state as much as by raw multiply throughput. Hailo's GenAI stack therefore uses a specific prefill plus token-by-token split with persistent cache machinery rather than compiling one generic dynamic sequence graph.

---

# Part II - PCIe transport and driver architecture

## Device discovery and BAR roles

Aesir's clean-room transport study of Hailo's public driver records this Hailo-10H PCIe model:

- vendor ID `0x1e60`;
- Hailo-10H device ID `0x45C4` in the studied profile;
- three important memory BAR roles:
  - **BAR0:** configuration, interrupt status/masks, channel completion bitmaps, address-translation configuration;
  - **BAR2:** VDMA engine registers;
  - **BAR4:** firmware-access / control mailbox window.

The kernel driver exposes a character-device/ioctl API to HailoRT. Aesir's HAILBRÚ work has progressively learned and independently reimplemented host-side pieces of this contract in Mojo.

## Single MSI interrupt model

The studied device/driver uses a single MSI vector rather than a large MSI-X vector table. The host discovers the reason for an interrupt by reading status registers. Several status reads are read-and-clear operations.

This creates a correctness rule:

> Read the status once, preserve the observed word, then interpret it. A second read may not see the same event.

The control and DMA completion domains share the interrupt mechanism. Aesir's worker and deadline machinery is valuable because it already treats completion as an owned event rather than casually polling shared mutable state.

## Firmware mailbox

The direct firmware-control path is conceptually a single-slot mailbox, not a classic host queue pair.

The clean-room 5.3-era study describes:

1. host writes a length-prefixed request into BAR4 command storage;
2. host raises a per-board ready flag, effectively ringing a doorbell for one of the on-chip CPUs;
3. firmware processes the request;
4. firmware signals completion;
5. host reads a response from a fixed response area.

Aesir recorded the 5.3-era studied offsets and completion bit, but those values must remain version-profile facts, not timeless architecture constants. Public 5.4 control-protocol layouts changed in meaningful ways.

Important distinction:

```text
firmware mailbox protocol != HailoRT hRPC protocol != LCU/context microcode
```

They are three different layers. Never merge their action/opcode namespaces.

## Bulk data: VDMA

The driver uses descriptor-ring DMA for bulk movement. The general model is:

```text
host memory
   |
   v
DMA mapping / scatter-gather or USERPTR representation
   |
   v
descriptor list
   |
   v
assigned VDMA channel
   |
   v
Hailo device memory / stream endpoint
   |
   v
completion interrupt and channel bitmap
```

Aesir has already established a lot of the lifecycle around this path, including list/channel ownership, mappings, IRQ workers, synchronization boundaries, deadlines, poisoning after uncertain failure, and cleanup ordering.

The remaining danger is to mistake lifecycle mastery for knowledge of the numerical program. DMA is the road. It is not the destination.

---

# Physical profile already observed by Aesir

In the 2026-10-24 same-file map acceptance, the recorded live profile included:

- H10H board identity;
- PCIe DMA type `0` in the observed property surface;
- one DMA engine reported by the interface;
- firmware-loaded state true;
- maximum descriptor page reported as 4096;
- host page size 16384 on the Pi kernel;
- session descriptor page of 512 in the selected session policy;
- assigned directional channels observed as 0 and 16 for the tested sessions;
- the existing allocation policy reserved large descriptor counts, but usage/capacity was explicitly not inferred.

The test physically mapped six sealed buffers through the real driver and later released them with the owning session lifecycle.

It deliberately performed no numerical request, no program activation, no RPC packet, and no DMA data transfer. That honesty boundary is one of the project's strongest engineering habits.

---

# Driver/session ownership model

Aesir has converged on a useful ownership philosophy:

```text
one fresh session/file
    owns
       -> descriptor lists
       -> directional channels
       -> connection
       -> mapped program/control buffers
       -> IRQ worker lifecycle
       -> cleanup order
```

This is better than passing detached file descriptors or raw pointers around the compiler. The most dangerous bugs in low-level accelerator runtimes are often lifetime bugs rather than math bugs.

The grouped-control implementation also enforces a **poison-on-uncertain-failure** rule. If an exchange may have partially affected the device, the client is no longer reused. Recovery requires a fresh owner. This should continue into numerical execution.

---

# Deadline model

Aesir's grouped RPC host path uses one total monotonic deadline across an exchange rather than resetting a timeout for each phase. That prevents a series of individually legal waits from becoming an unbounded overall operation.

The model is roughly:

```text
start total budget
  -> preflight
  -> host/device ownership transition
  -> D2H posting
  -> H2D launch
  -> IRQ / completion wait
  -> sync back to CPU
  -> parse / correlate reply
  -> cleanup if admitted
end
```

Important caveat: user-space deadline checks do not magically preempt a synchronous kernel call already in progress. A separate outer process watchdog bounds catastrophic hangs. Keep both concepts distinct.

---

# Part III - HailoRT and GenAI runtime

## Runtime stack

The current public Hailo software stack can be understood as:

```text
Application / Ollama / GenAI API
             |
          HailoRT
             |
     runtime resource manager
             |
     driver / hRPC / firmware
             |
         Hailo-10H
```

HailoRT is open source under MIT for its core user-space runtime. The PCIe driver repository is GPLv2. Hailo's Dataflow Compiler remains proprietary.

For Project Aesir, HailoRT is both:

- a working route already used for compiled-model inference;
- a public behavioral specification from which Aesir can learn interface facts.

It is not the final native source-model compiler.

## GenAI server responsibilities

Public HailoRT GenAI code shows that LLM creation is more than loading a graph. The server/runtime manages:

- HEF resource discovery/loading;
- tokenizer and model resources;
- KV-cache acquisition and exclusivity;
- pre-processing configuration;
- prompt handling;
- prefill execution;
- token-by-token execution;
- cache offset advancement;
- generation parameters;
- post-processing / token selection;
- context clearing and resource release.

An important public behavior is that KV cache is acquired as a managed shared resource. Multiple model/session assumptions around that cache must therefore be explicit in Aesir as its native runtime matures.

## Current official GenAI model patterns

The current Hailo GenAI model zoo includes models such as Qwen2/Qwen2.5 1.5B, Qwen2.5-Coder 1.5B, Qwen3 1.7B, Llama 3.2 1B, DeepSeek-R1-Distill-Qwen 1.5B, VLM variants, and Whisper models.

Published LLM entries commonly use:

- 2048 token context;
- A8W4 numerical schemes;
- symmetric group-wise or channel-wise weight quantization;
- separate prefill and token-by-token behavior.

This is strong evidence for the numerical regime Aesir should prioritize first: **INT8-ish activations with INT4 weights**, while retaining higher precision where the runtime/compiler contract requires it.

It is not evidence that every operator should be forced into 4-bit weights or 8-bit activations.

---

# The Hailo LLM execution contract

An independent 2026 MIT-licensed experimental project, `l-nmch/hailo-10h-llm-compiler`, is extremely useful as a behavioral research source. It still relies on Hailo's proprietary DFC and therefore does **not** satisfy Aesir's product target. Its value is that it experimentally documents what the public GenAI runtime expects.

Treat its findings as EXTERNAL EXPERIMENTAL evidence, to be independently tested or translated into original requirements, not copied implementation.

The central pattern is:

```text
model
  |
  +--> __prefill network group
  |       consumes a prompt chunk
  |       produces first-token logits
  |       writes KV state
  |
  +--> __tbt network group
          consumes one token at a time
          reads existing KV state
          writes the next KV entry
          produces next-token logits
```

Persistent state is the heart of decoding. If the prefill and TBT groups disagree about cache layout, generation may look superficially linguistic yet become incoherent.

---

# KV cache: the most important external finding

The independent compiler project found and fixed a real failure in which prefill was numerically correct while token-by-token generation degraded.

The key observations were:

- prefill logits were near the float reference;
- TBT computation with cache effectively masked out was also near the reference;
- TBT became wrong specifically when reading previously written cache entries;
- cache scales matched;
- mask convention was correct;
- probing individual cache entries showed mixtures of prompt tokens rather than a clean one-token-per-entry mapping.

The root cause was a **layout disagreement**. HailoRT treats cache memory as a ring of token entries. Each entry must be arranged so that one token's feature data corresponds to one cache entry. If prefill writes one physical layout and TBT interprets another, rotating the cache pointer mixes token features.

The experimental fix forced explicit layout conversions on **both** the prefill and TBT cache edges so both groups used the same token-major contract.

Aesir lesson:

> KV cache must become an explicit backend object with a declared logical shape, physical entry size, padding, cache ID, read offset, write offset, and layout conversion policy. Do not leave cache layout as an incidental result of tensor placement.

Public HailoRT `cache_manager.cpp` reinforces this. Cache entry size is derived from a hardware feature dimension, entries are padded according to descriptor/page constraints, backing storage is shared by cache ID, and read offsets are updated modulo cache length.

For Aesir, define a first-class cache record such as:

```text
CachePlan
  cache_id
  logical_tokens
  read_length
  write_length
  logical_features_per_token
  physical_entry_bytes
  padded_entry_bytes
  total_bytes
  source_layout
  device_layout
  prefill_writer_layout
  tbt_reader_layout
  tbt_writer_layout
  initial_read_offset
  rotation_rule
```

The exact device fields remain to be learned, but the compiler IR should already express these semantics.

---

# RoPE runtime contract

The independent LLM compiler found that Hailo's LLM runtime expects position-related buffers whose widths are already expanded by head count, and that K and Q can have different final widths because grouped-query attention uses fewer KV heads than Q heads.

For a GQA model:

```text
Q RoPE width ~ theta_size * num_attention_heads
K RoPE width ~ theta_size * num_key_value_heads
```

The failure mode came from allowing both the host/runtime and the graph to perform tiling. The result was double expansion and a layout mismatch.

Aesir lesson:

- RoPE must be represented as a semantic operation, not merely a constant table.
- Track Q heads and KV heads independently.
- Track whether the host, program, or device is responsible for expansion.
- Never infer a common width just because both tensors use the same head dimension.
- Position conventions must be coupled to tokenizer/BOS conventions and cache offsets.

---

# Attention mask contract

Another external finding revealed a subtle broadcast error: element-wise `repeat` semantics can produce patterns like `AABBCC`, while attention-head broadcasting requires whole-block tiling like `ABCABC`.

The reliable approach in that experimental flow was to provide the mask already tiled into the shape expected by its consumers rather than relying on an ambiguous in-graph repeat operator.

Aesir lesson:

Represent the mask's logical axes explicitly:

```text
[batch, query_position, head, key_position]
```

Then make layout lowering deliberate. Do not represent a mask as merely a flat width and hope a generic repeat operation preserves head semantics.

For sliding-window attention, mask generation may remain a host/compiler semantic responsibility even when the numerical graph is otherwise unchanged.

---

# Tokenizer and BOS are part of numerical correctness

The independent project found that different tokenization paths could disagree on whether a BOS token is inserted. A one-token offset changes:

- every RoPE position;
- every causal-mask row;
- cache entry numbering;
- the position at which logits are sampled.

It also observed server-side token-by-token detokenization behavior that interacted badly with a tokenizer decoder step that strips leading spaces.

Aesir lesson:

A model execution record should preserve:

```text
TokenizerIdentity
  tokenizer hash
  vocab identity
  BOS policy
  EOS policy
  chat template identity
  special token IDs
  prompt token IDs actually submitted
  decoded token IDs actually returned
```

When debugging numerical drift, compare token IDs before comparing logits. Text that looks the same is not enough.

---

# Runtime configuration sidecar behavior

The independent project discovered a silent configuration mismatch in which the server expected a key corresponding to `prefill_input_tokens_count`, while a differently named key was silently ignored and a default was used.

The general lesson is broader than the exact key:

> Every runtime sidecar field must be verified against the code that consumes it. Silent defaults are dangerous because they look like valid execution.

For Aesir's native route, prefer typed Mojo structures over loosely named JSON wherever possible. If an external compatibility layer uses JSON, validate every required key and reject unknown or missing fields rather than inheriting silent defaults.

---

# Part IV — Numerical Reality: What the Hailo-10H Must Actually Compute

## Quantization is part of the machine contract

A source model's quantization format and a device's numerical format are not the same thing.

A GGUF file may store weights in Q2_K, Q3_K, Q4_K, Q5_K, Q6_K, Q8, IQ4, or other source encodings. Those formats answer a storage question:

> How are the original model parameters represented in the source file?

The Hailo-10H asks a different question:

> In what precision, grouping, layout, scale domain, accumulator width, and saturation policy will the accelerator execute this operation?

Aesir already contains source readers for a useful collection of GGUF representations. That work should feed a device-neutral numerical IR rather than be treated as device code directly.

A useful normalized value is:

```text
QuantizedTensorPlan
  source_tensor_id
  logical_dtype
  source_encoding
  device_weight_precision
  device_activation_precision
  grouping_axis
  group_size
  scale_representation
  zero_point_representation
  accumulator_precision
  rounding_policy
  saturation_policy
  packed_layout
  physical_shards[]
```

The compiler should be able to answer all of those fields before it emits any hardware configuration bytes.

### Current public Hailo LLM pattern

Current Hailo generative-AI model publications commonly describe decoder models using 8-bit activations and 4-bit weights. The external Hailo-10H LLM compiler project likewise reports success with a mixture centered on A8W4 for matrix-heavy layers and wider precision for special paths such as embeddings.

Treat this as a strong architectural lead, not a universal rule. Aesir's final policy must be based on measured accuracy and hardware acceptance for each architecture class.

### Why residual paths are dangerous

The values most likely to punish low precision are not necessarily the largest weight matrices. Transformer residual streams, normalization intermediates, softmax statistics, gating products, and outlier channels can have very different dynamic ranges.

The independent compiler project observed model classes where a superficially reasonable low-precision recipe produced coherent small models but degraded larger hidden sizes. It also recorded cases where higher precision in selected paths materially helped. This is exactly why Aesir should attach numerical policy to operations rather than merely say "the model is INT4."

A useful operation policy record:

```text
NumericalPolicy
  op_id
  input_formats[]
  weight_format
  accumulator_format
  output_format
  calibration_method
  clipping_method
  outlier_policy
  verification_tolerance
```

The compiler should refuse to emit hardware code if any required policy is unresolved.

---

## External experimental quantization lessons

The independent `l-nmch/hailo-10h-llm-compiler` project is useful because it has already exercised real Hailo-10H hardware, even though its DFC-dependent workflow is outside Aesir's product scope.

Its documented experimental recipe includes these lessons:

1. Generic CNN optimization defaults are not automatically safe for duplicated LLM prefill/TBT graphs.
2. KV-cache configuration is a first-class compiler concern.
3. Some element-wise fusions can change graph correspondence in ways that hurt an LLM.
4. Embedding/input paths may require wider precision than the main weight matrices.
5. Calibration data must match the runtime representation of positions, masks, and cache behavior.
6. Software emulation can be wrong in ways that real silicon is not, so final acceptance must occur on hardware.

The same project reports that Hailo's production LLM flow uses more specialized techniques than its own simple recipe. It cites QuaROT-style rotation and GPTQ-family quantization in Hailo's published material. For Aesir, the lesson is not "copy a recipe." It is:

> A production LLM compiler needs a dedicated outlier and quantization strategy. Merely decoding GGUF weights and repacking them is not enough.

### Recommended Aesir quantization progression

Use an incremental ladder:

1. **Exact or wider-precision primitive proof.** Prove a tiny operation before aggressive quantization.
2. **INT8-weight / INT8-activation proof if supported by the discovered path.** Favor numerical simplicity while learning hardware semantics.
3. **A8W4 matrix path.** Introduce 4-bit weights after the layout and accumulator rules are known.
4. **Mixed precision.** Keep numerically sensitive operations wider.
5. **Outlier transformation.** Add rotation/equalization or another mathematically justified method only after a clean baseline exists.
6. **Architecture-specific policy.** Qwen, Llama, Mistral, and future families should share framework machinery without pretending their numerical quirks are identical.

At every stage, compare against a small test-only mathematical oracle. A host oracle is permitted as verification machinery; it must never become the product's LLM inference route.

---

# Part V — What Aesir Already Knows About Source Models

## Source ownership is a solved problem relative to the remaining work

The source side is one of the strongest parts of the current implementation.

Aesir has already built and repeatedly qualified machinery for ordinary model ownership, parsing, source identity, and mathematical lowering. The exact breadth changes as development continues, but the present architecture contains the following major pieces.

| Domain | Current state | Finish-line meaning |
|---|---|---|
| GGUF ownership | Strong | Ordinary GGUF can be sealed, parsed, retained, and read under owned lifetime rules |
| Safetensors ownership | Strong | Indexed and unindexed ordinary sources have owned metadata/backing paths |
| Shards/model root | Strong | Source files are resolved beneath the model root with explicit provenance |
| Tensor inventory | Strong | Names, axes, shapes, dtype/source storage can be carried into compiler stages |
| GGUF quant readers | Broad and growing | Q2/Q3/Q4/Q5/Q6/Q8/IQ4-family source components can be reconstructed for compiler use |
| Projection bindings | Strong | Q/K/V/output roles, widths, ties, and biases are represented |
| Rotary semantics | Strong mathematical IR | Rotary basis, recipes, scaling and modifiers have explicit compiler representation |
| Activation semantics | Strong mathematical IR | Source activation selection and expansion are represented |
| Cache/session graph | Strong mathematical IR | Cache-return/session intent and lifetimes are represented |
| Window/mask semantics | Strong mathematical IR | Causal/window behavior is represented rather than hidden in defaults |
| Dynamic scaling | Active / broadening | Dynamic/context-dependent policy continues to be qualified |
| Matrix scheduling | Host mathematical schedule exists | It does not yet equal Hailo placement or executable scheduling |
| Device numerical encoding | **Missing decisive bridge** | Must map mathematical operations to actual Hailo configuration and code |

The central design principle should remain:

> Never throw away source identity merely because a later compiler stage has a convenient lowered representation.

A physical device result should be traceable back through:

```text
result token/logit
  → device output buffer
  → physical output descriptor
  → placed operation
  → lowered operation
  → mathematical graph operation
  → source tensor binding
  → source file + extent + digest
```

That lineage will make debugging radically easier once numerical execution begins.

---

## The source compiler's next transformation boundary

Today, Aesir can get roughly this far:

```text
ordinary source file
  ↓
owned immutable bytes
  ↓
parsed tensor/config metadata
  ↓
typed decoder architecture
  ↓
mathematical operations
  ↓
source-bound schedules / byte tiles
  ↓
????????????????????????????????
  ↓
Hailo-executable configuration
```

The missing stage should be designed explicitly rather than allowed to grow accidentally.

Call it conceptually:

```text
HailoLoweringPipeline
```

Its output should not initially be "bytes." Its output should be a typed intermediate representation whose every field has a known reason for existing.

Suggested layers:

```text
ModelIR
  ↓
NumericalIR
  ↓
TiledIR
  ↓
PlacedIR
  ↓
ContextIR
  ↓
EncodedProgram
```

### ModelIR

Contains architecture semantics:

- normalization;
- Q/K/V projection;
- attention;
- rotary application;
- MLP gating;
- residual connections;
- output normalization;
- lm_head;
- cache reads/writes.

### NumericalIR

Adds:

- activation precision;
- weight precision;
- scales;
- zero points if applicable;
- accumulator behavior;
- clipping and saturation;
- explicit transformations such as rotations/equalization.

### TiledIR

Adds:

- logical tensor tiles;
- matrix partitioning;
- shard boundaries;
- cache-entry geometry;
- large-vocabulary output shards;
- host-composed vs on-chip-composed results.

### PlacedIR

Adds only facts that have been qualified for the real Hailo-10H:

- cluster/subcluster assignment;
- local-memory region assignment;
- input-aligner/resource selection;
- L2/L3 windows;
- physical resource bitmaps;
- DMA channels where relevant.

Unknown physical fields remain `Unknown`, not zero.

### ContextIR

Adds:

- context actions;
- sequencer configuration;
- dependencies;
- completion conditions;
- configuration-transfer ordering;
- cache/context switching.

### EncodedProgram

Only this final stage produces the packed values that a Hailo-10H can consume.

This layering gives Yrsa a powerful debugging rule:

> If an error is visible before encoding, do not debug bytes. If an error only appears after encoding, prove the prior IR is still correct before touching source semantics.

---

# Part VI — Learning From HEF Without Making HEF the Product

## HEF is a map of responsibilities

Aesir's clean-room HEF study is useful precisely because the project does not want users to depend on vendor-precompiled HEFs.

The important idea is not the container itself. It is the list of responsibilities a working compiler must satisfy.

A compiled Hailo program logically carries:

1. target and compatibility metadata;
2. network groups;
3. core-operation structure;
4. contexts;
5. physical layouts;
6. scheduler/context-switch actions;
7. tensor and stream metadata;
8. quantization metadata;
9. packed configuration/control words;
10. external resources such as weights or other blobs;
11. feature flags;
12. integrity information.

Aesir may encode those responsibilities in its own internal structures, but it cannot wish any of them away.

## The key distinction: envelope versus executable content

The outer container is bookkeeping.

The contexts and packed configuration are what make the hardware compute.

This distinction prevents a recurring failure mode:

```text
"We generated a valid-looking header"
      ≠
"We generated an executable NPU program"
```

Likewise:

```text
"The runtime parsed our metadata"
      ≠
"The arithmetic fabric accepted our operation"
```

Aesir's own documentation has generally been disciplined about this boundary. Keep it that way.

---

## Program architecture namespace trap

One of the most important concrete interface facts already discovered is that Hailo's architecture identifiers live in more than one namespace.

For the public program/container schema studied by Aesir:

- `HAILO1XH` uses program-side value **103**;
- the old program-side `HAILO10H` slot **5** is deprecated.

In the runtime device architecture enum, Hailo-10H is represented by a different value, **6**.

Therefore:

```text
program_target = UInt32(runtime_device_arch)
```

is invalid reasoning.

Always convert through an explicitly qualified mapping with provenance and version.

Suggested type discipline:

```text
struct RuntimeDeviceArch
struct ProgramTargetArch

fn program_target_for(device: RuntimeDeviceArch,
                      runtime_version: Version,
                      program_version: Version) raises -> ProgramTargetArch
```

Do not use raw integers at API boundaries where the namespace matters.

---

# Part VII — Known Outer Program Structure and Integrity

## Version-3 public outer layout facts

Aesir's public-source study established a version-3 program/container header size of **56 bytes** for the inspected HailoRT generation.

The public format uses big-endian storage for the outer integer fields, even though other Hailo interfaces such as hRPC use little-endian packed values.

Conceptually:

```text
0x00  magic                      u32 BE
0x04  format version             u32 BE
0x08  protobuf byte count        u32 BE
0x0C  residue XXH3-64            u64 BE
0x14  CCW section byte count     u64 BE
0x1C  padding byte count         u32 BE
0x20  additional-info byte count u64 BE
0x28  protobuf XXH3-64           u64 BE
0x30  reserved                   8 bytes zero
```

The public magic observed by the study is `0x01484546`.

This is format knowledge, not permission to claim that a generated payload is a valid hardware program.

### Section arithmetic

For a 56-byte header `H`, protobuf size `N`, CCW-section size including preceding alignment `W`, padding `P`, and additional-information size `A`:

```text
protobuf:    [H, H+N)
padding:     [H+N, H+N+P)
CCW bytes:   [H+N+P, H+N+W)
additional:  [H+N+W, H+N+W+A)
```

All arithmetic must be checked for overflow and extent consistency.

### Integrity domains

The public parser behavior studied by Aesir distinguishes checksum modes.

- With a nonzero protobuf checksum, the parser validates the protobuf domain separately.
- With the alternate whole-residue mode, the bytes after the header are covered as a complete residue.
- XXH3-64 is a corruption checksum, not a cryptographic identity and not the same thing as any internal LCU/CCW integrity mechanism.

For Aesir, preserve at least three concepts separately:

```text
source_identity_hash       cryptographic, e.g. SHA-256
outer_container_checksum   format compatibility/corruption
hardware_program_integrity device-specific, only when actually qualified
```

Never let one field stand in for another.

---

# Part VIII — Program Delivery Machinery Already Built

## Separate metadata and program payloads

Aesir's current original payload staging deliberately keeps two things distinct:

```text
part 0: control metadata
part 1: program bytes
```

The control metadata is shaped to the currently qualified fixed control-buffer path, while the program is retained as its own byte range.

This is good architecture because an arbitrary invented concatenation would bake a transport assumption into the compiler.

Current staging can:

- own source bytes;
- validate extents;
- validate the currently qualified outer integrity domain;
- generate deterministic metadata;
- retain/copy windows safely;
- preserve lifetimes across moves and destruction of local temporaries.

It cannot yet claim:

- program acceptance by the remote resource manager;
- activation;
- physical placement;
- numerical correctness;
- execution.

### Aesir delivery invariant

A generated program should have a single identity object:

```text
ProgramIdentity
  source_model_digest
  compiler_version
  target_profile_digest
  numerical_plan_digest
  placement_digest
  encoded_program_digest
  transport_metadata_digest
```

The runtime should be able to print this identity before a physical run. That makes every result reproducible and debuggable.

---

# Part IX — Known Sequencer and LCU Control Records

## Context record IDs are not arithmetic opcodes

Aesir has qualified several public packed context-switch records. These control execution machinery but do not describe the inner arithmetic operation by themselves.

This distinction is critical.

### Sequencer trigger

Known packed form from the studied public interface:

```text
common header
  action        u8
  timestamp     u32

trigger body
  cluster_index u8
  configuration 43 bytes
```

Complete trigger extent: **49 bytes**.

The 43-byte configuration contains:

| Field | Width | Body-relative offset |
|---|---:|---:|
| initial_l3_cut | u8 | 0 |
| initial_l3_offset | u16 | 1 |
| active_apu | u32 | 3 |
| active_ia | u32 | 7 |
| active_sc | u64 | 11 |
| active_l2 | u64 | 19 |
| l2_offset_0 | u64 | 27 |
| l2_offset_1 | u64 | 35 |

The names are useful. They do **not** tell us safe Hailo-10H values.

Aesir must independently qualify:

- how a logical operation chooses a cluster;
- what the active APU bitmap means on this exact device;
- how input-aligner selection maps to tensor geometry;
- what subcluster bitmap corresponds to a legal placement;
- what L2 offsets are valid;
- how initial L3 cut/offset correspond to actual memory regions.

### Sequencer completion

Known compact form:

```text
common header: action u8 + timestamp u32
body: sequencer_index u8
```

Complete extent: **6 bytes**.

Again, this establishes a wire record, not a valid physical index.

---

## Additional LCU control records

The public interface study also established packed control records for:

- nondefault LCU enable, context action ID 4;
- LCU disable, context action ID 5;
- batch switch, context action ID 36.

The studied packed LCU identifier uses:

```text
bits 0..3 : unit
bits 4..6 : cluster
bit 7     : reserved
```

This bit packing must not be turned into a claim that the hardware contains exactly 16 usable units per cluster or 8 safe clusters. Bit width is encoding capacity, not resource census.

The next question is not "Can we serialize these?" Aesir already can serialize host-side records.

The real question is:

> Which values correspond to a legal placed program on the actual Hailo-10H, and what numerical configuration must exist before these control records trigger anything meaningful?

---

# Part X — The Missing Bridge: Numerical CCWs, Resource Geometry, and Placement

## This is the actual finish-line problem

After all current work, the decisive unknown is still the mapping:

```text
Transformer operation
      ↓
Hailo arithmetic/dataflow configuration
      ↓
physical resource placement
      ↓
context/control records
      ↓
program bytes accepted by the device
```

Aesir's public-source research has intentionally refused to invent the following:

- arithmetic opcodes;
- register bit positions;
- CCW field meanings;
- Hailo-10H physical cluster/resource geometry;
- input-aligner configuration values;
- SRAM/L2/L3 placement rules;
- microcode instruction widths;
- internal CRC parameters;
- valid activation/program trigger sequence for an original numerical payload.

That refusal is correct.

The next phase is therefore a **hardware compiler reverse-specification problem**, not a normal API-integration problem.

---

## What a complete physical operation needs

For a minimal matrix or vector primitive, Yrsa should demand evidence for each layer below.

### 1. Numerical definition

Example:

```text
C = A × B + bias
```

with exact:

- dimensions;
- signedness;
- scaling;
- accumulator width;
- rounding;
- saturation;
- output representation.

### 2. Tile plan

```text
A tile geometry
B tile geometry
C tile geometry
iteration order
partial accumulation plan
```

### 3. Physical resource plan

```text
cluster
subclusters
APUs / compute units
input aligner
local-memory banks/windows
L2/L3 offsets
```

### 4. Data-movement plan

```text
host → device input
weight/resource load if required
intermediate movement
result → host
```

### 5. Static configuration

The quasi-static resource settings that establish the dataflow fabric.

### 6. Dynamic program / LCU actions

The compact per-layer or per-context actions that advance the configured fabric.

### 7. Completion contract

Which exact event means it is safe to read output or reuse storage.

### 8. Cleanup contract

How resources become known idle, not merely locally closed.

If even one of these remains unknown, the operation is not yet qualified for a physical numerical run.

---

## Patents are architectural maps, not instruction manuals

Hailo patents are valuable because they reveal how the designers think about the hardware:

- hierarchical compute and memory;
- static configuration separated from dynamic layer-control instructions;
- compiler-generated instruction sequences;
- memory windows and limited/noncontiguous access;
- program-length and integrity checking;
- resource activation and layer sequencing.

They are not sufficient to derive a Hailo-10H instruction encoder safely.

A patent diagram's field names and illustrative values must stay in a research notebook until independently tied to:

- public source declarations;
- exact Hailo-10H observed behavior;
- or a controlled physical experiment.

This is one of the most important epistemic rules in the whole project.

---

# Part XI — The Independent LLM Compiler Project as a Behavioral Oracle

## Why it matters

The external project `l-nmch/hailo-10h-llm-compiler` does not satisfy Project Aesir's final user experience because it requires Hailo's Dataflow Compiler.

Nevertheless, it has already spent a great deal of engineering effort discovering what the Hailo LLM stack expects. That makes it an excellent **behavioral oracle and research map**.

Do not copy its implementation into Aesir merely because it works. Instead, extract questions, invariants, and test cases.

---

## Finding: the model must end in logits over the vocabulary

A hidden-state output is not a language-model output.

The independent pipeline found that the Hailo GenAI runtime expects a final vocabulary distribution. Its working graph includes an `lm_head` and produces the final position's vocabulary logits.

Conceptual output:

```text
[batch, one_position, vocabulary]
```

rather than:

```text
[batch, sequence, hidden]
```

or a full sequence of vocabulary logits if the runtime only consumes the next-token position.

Aesir should model this explicitly:

```text
DecoderOutputPlan
  final_norm
  last_position_selection
  lm_head
  vocabulary_shards[]
  host_or_device_merge_policy
```

---

## Finding: large vocabularies require sharding

Qwen-family tokenizers can have vocabularies around 152K entries. A single huge hidden-to-vocabulary projection can become a placement problem.

The independent project inspected a production-style Qwen2.5 Hailo artifact and observed the vocabulary output split into multiple similarly sized output streams whose widths sum to the full vocabulary.

Its own experiments found that a monolithic `lm_head` could fail placement and that the compiler's multi-output/fusion behavior introduced further complications. Eventually it found a workable sharding strategy for its DFC pipeline.

Aesir's important takeaway is independent of DFC:

> `lm_head` sharding belongs in TiledIR and must be designed as a first-class operation.

Suggested representation:

```text
LmHeadPlan
  hidden_size
  vocab_size
  shards[]:
    vocab_start
    vocab_count
    weight_extent
    output_buffer
  reduction: none
  host_merge: concatenation or distributed top-k
```

For efficiency, Aesir does not necessarily need to materialize all vocabulary logits into one giant host array before choosing a token. Once correctness is established, a distributed top-k/argmax merge across shards may be preferable. But correctness comes first.

---

## Finding: small-model success does not guarantee large-model fidelity

The external compiler has an especially useful warning for Aesir.

It achieved coherent generation on a 25M-parameter TinyStories model, but recorded real-hardware numerical degradation on larger hidden sizes and a Qwen2.5-0.5B checkpoint even after structural compilation succeeded.

Its data set is experimental and should not be generalized into a universal Hailo law. But the lesson is profound:

```text
program accepted by device
      ≠
correct neural-network numerics
```

Aesir needs numerical acceptance gates at every scale.

A source model is not "supported" merely because:

- it parses;
- it fits memory;
- its program uploads;
- or it returns outputs.

Support requires measured numerical behavior.

---

# Part XII — The Numerical Verification Ladder

## Never jump directly from bytes to chat quality

When the first native program runs, a bad answer like `7` instead of `5` will not tell us whether the problem is:

- source parsing;
- quantization;
- scale packing;
- tensor layout;
- matrix tiling;
- resource placement;
- DMA ordering;
- cache rotation;
- RoPE position;
- attention mask;
- softmax;
- output shard order;
- tokenizer behavior.

The verification ladder must isolate these layers.

### Level 0: source byte identity

Prove that the tensor components reaching the compiler equal the intended source bytes/components.

Aesir already has strong machinery here.

### Level 1: source mathematical value identity

For selected blocks, reconstruct source values with an independent test oracle and compare.

### Level 2: numerical-plan identity

Given a source tensor and policy, independently calculate the exact quantized representation that the Hailo lowering intends to use.

Check:

- scale;
- code values;
- grouping;
- padding;
- packing order.

### Level 3: first device primitive

Use the smallest possible hardware operation whose output can be exhaustively predicted.

Examples in increasing complexity:

```text
identity / copy-like numerical path
vector add
small dot product
small matrix multiply
```

Only choose an operation once its real Hailo encoding is known. Do not invent a "safe" opcode.

### Level 4: transformer primitives

Individually validate:

```text
RMSNorm
linear projection
RoPE
QKᵀ
scale
mask addition
softmax
attention × V
SwiGLU / gated MLP
residual add
```

### Level 5: one decoder block

Feed synthetic hidden state and cache tensors into one layer and compare complete outputs against an independent test oracle.

### Level 6: multi-layer decoder without tokenization ambiguity

Use explicit token IDs and fixed positions. Compare final logits.

### Level 7: prefill

Run a short real prompt with explicit token IDs and compare:

- selected hidden checkpoints if observable;
- final logits;
- argmax;
- top-k.

### Level 8: one TBT step

Populate a known cache, advance exactly once, compare next-token logits.

### Level 9: repeated TBT

Run 8, then 32, then context-boundary sequences while checking cache offset and numerical drift.

### Level 10: normal chat

Only now judge coherent language behavior.

---

## Useful numerical metrics

For vectors or logits, record more than one statistic:

```text
max absolute error
mean absolute error
relative error where defined
cosine similarity
Pearson correlation
argmax agreement
top-k overlap
KL divergence for normalized distributions
```

Do not rely on cosine alone. Two vectors can have high cosine and still disagree in the few logits that choose the next token.

For deterministic primitive tests, exact integer equality should be preferred whenever the device representation makes it possible.

---

# Part XIII — Physical Experiment Safety and Evidence Discipline

## The current Aesir physical style is a strength

The repository's Hailo campaign has developed unusually strict physical-test discipline. Preserve it.

For every new hardware slice:

1. publish the exact contract before implementation;
2. freeze relevant source/test/oracle identities;
3. host-qualify all pure logic first;
4. record installed kernel, driver, runtime, firmware or device identity as available;
5. reject mismatched target profiles before side effects;
6. run the smallest bounded physical child;
7. never repeat an uncertain side effect merely because the result was inconvenient;
8. preserve raw evidence;
9. state exactly what the run proved and what it did not prove.

### Distinguish local cleanup from remote quiescence

Closing a file descriptor can prove local ownership release.

It does not automatically prove:

- firmware destroyed a logical model object;
- DMA is no longer active;
- the NPU is idle;
- a remote context is gone;
- a potentially completed operation did not execute.

Continue recording these separately.

### Deadline rule

Userspace timeouts can bound orchestration. They cannot necessarily preempt a synchronous kernel call already in progress.

Therefore distinguish:

```text
admission deadline
operation completion evidence
outer process watchdog
cleanup deadline
```

A late return should be rejected without pretending the kernel call never happened.

---

# Part XIV — Immediate Frontier: What Yrsa Should Do Next

## Step 1: complete the contracted physical typed lifecycle

At the snapshot used for this book, host qualification exists for the grouped create/identify/destroy lifecycle.

The next bounded physical contract is designed around one fresh device session and the typed sequence:

```text
CREATE   action 20
IDENTIFY action 22
DESTROY  action 21
```

with actual mapped H2D/D2H control storage, observed transfer returns, completion correlation, cache ownership transitions, a single overall lifecycle budget, and conservative cleanup.

This is the correct next transport experiment because it proves that Aesir's grouped Mojo transport and typed device-resource semantics meet on the real hardware.

Acceptance should remain narrow:

- exactly the expected typed response fields;
- exact frame correlation;
- observed assigned directional completions;
- expected device identity;
- confirmed logical destruction if the reply proves it;
- exact local resource accounting.

It still must **not** be called numerical execution.

---

## Step 2: qualify a generic grouped request/response transport primitive

Once the typed lifecycle works physically, extract the general facts the numerical program path will need:

```text
How are grouped input spans described?
What does the positive launch return count mean in practice?
What exact completion evidence corresponds to each direction?
When must cache sync occur?
What storage remains owned until completion?
How is a late completion quarantined?
```

The goal is not a general arbitrary RPC API. The goal is a rigorously owned transfer primitive that later numerical/program messages can reuse.

---

## Step 3: qualify program-object creation and payload transfer semantics

Aesir already stages program metadata and bytes host-side.

The next program-specific research must determine, from qualified public interfaces and controlled device observations:

- the exact creation request that allocates the remote program/infer resource;
- the payload-transfer phase;
- how offsets/chunks are represented;
- completion and readiness;
- program finalization;
- how failure tears down partially created objects;
- which object handle is later used for activation/configuration.

Do not choose arbitrary chunk sizes or assume a single buffer because it is convenient.

A program may be accepted structurally without being numerically valid. That is still useful evidence if labeled correctly.

---

## Step 4: find the smallest independently justified numerical configuration

This is the real research fork.

Before a physical arithmetic test, Yrsa must have independently qualified:

```text
one operation type
one legal resource placement
one legal tensor layout
one legal precision
one legal configuration stream
one legal trigger/completion sequence
```

The ideal first operation is not necessarily vector addition. It is whatever operation has the **best public evidence and smallest configuration surface**.

Selection criteria:

1. public field information is strongest;
2. expected output can be calculated exactly;
3. little or no state persists after completion;
4. tiny buffers;
5. one context if possible;
6. no KV-cache;
7. no multicontext scheduling;
8. no tokenizer or model-format ambiguity.

Only after such an operation is fully described should a physical numerical program be emitted.

---

## Step 5: move from primitive to small matrix engine proof

Once one numerical operation is verified, build a tiny matrix contraction because transformer inference lives and dies on GEMM-like work.

Prove progressively:

```text
1×N dot
small M×K × K×N
multiple tiles
partial accumulation
quantized weights
quantized activations
mixed precision
```

For every test, save:

- source values;
- numerical IR;
- tile plan;
- physical plan;
- emitted program;
- exact device input bytes;
- exact device output bytes;
- independent expected output.

This data set will become the golden corpus for future compiler changes.

---

# Part XV — Transformer Bring-Up Roadmap

## Milestone A: linear projection

Target:

```text
Y = XW + b
```

Prove:

- sharding;
- tiling;
- quantized weight packing;
- accumulator behavior;
- bias path;
- output scale.

This single primitive unlocks Q/K/V projections, output projection, MLP up/gate/down projections, and lm_head.

## Milestone B: RMSNorm

RMSNorm is numerically sensitive and common across Llama/Qwen/Mistral families.

Explicitly prove:

```text
mean(x²)
+ epsilon
rsqrt
x * rsqrt
* learned weight
```

If Hailo realizes this as multiple primitive operations rather than one native op, that is fine. Model it as a compiler recipe.

## Milestone C: RoPE

Use explicit positions. Test one head before all heads.

Verify:

- basis frequency;
- interleaving convention;
- Q width;
- K width;
- scaling variants;
- model-specific modifiers.

The external Hailo compiler's asymmetric Q/K runtime widths should be treated as a valuable test hypothesis.

## Milestone D: attention score path

Prove:

```text
QKᵀ
scale
causal/window mask addition
softmax
```

This should be tested with tiny dimensions where every score is inspectable.

## Milestone E: attention value path

Prove:

```text
softmax(scores) × V
output projection
```

## Milestone F: gated MLP

Prove the architecture's actual activation:

```text
up = X W_up
gate = X W_gate
h = activation(gate) * up
out = h W_down
```

Do not hard-code SwiGLU as universal. Carry source activation semantics from ModelIR.

## Milestone G: one complete decoder layer

At this point the compiler should run one layer from explicitly supplied hidden state and cache tensors.

The acceptance artifact should contain every intermediate numerical checkpoint that can be observed or independently reconstructed.

## Milestone H: prefill graph

Assemble multiple layers with:

- explicit token/embedding input;
- explicit causal mask;
- explicit position inputs;
- cache outputs;
- final normalization;
- lm_head;
- vocabulary shards if required.

## Milestone I: TBT graph and persistent cache

Do not begin by trying to reproduce a 2048-token production cache.

Use a tiny ring first:

```text
cache_length = 8 or similarly small supported configuration
prefill = 3 or 4 tokens
one TBT token at a time
```

Test wraparound explicitly.

## Milestone J: real small model

Choose a small decoder that still has the architectural features Aesir wants to support:

- RMSNorm;
- RoPE;
- GQA or MHA;
- gated MLP;
- cache;
- normal lm_head.

A tiny model is a compiler integration test, not the final product target.

## Milestone K: 1B-class model

Once the small model is numerically stable, move to the class that matters for the Hailo-10H's realistic GenAI use.

Use the working HailoRT Qwen2.5-1.5B result as a behavioral baseline for the device, but not as the native compiler's implementation dependency.

---

# Part XVI — Runtime Contract for Native LLM Execution

## Conceptual six-input pattern

The independent compiler's working Hailo LLM graph presents a useful conceptual runtime pattern consisting of:

1. primary model input / embedding-related input;
2. a fully prepared attention mask;
3. K-side RoPE cosine data;
4. K-side RoPE sine data;
5. Q-side RoPE cosine data;
6. Q-side RoPE sine data.

Exact names, encodings, and whether Aesir's final native compiler should use identical interfaces remain to be independently qualified.

The broader lesson is that some values a normal PyTorch graph computes internally may be supplied or transformed specially by the Hailo runtime/compiler contract.

Aesir's compiler should therefore have a clear split:

```text
HostPreparedInputs
DevicePreparedInputs
DeviceComputedValues
PersistentDeviceState
```

Do not let a convenience path blur which side owns a value.

---

## Prefill versus TBT

Aesir should model prefill and TBT as separate execution plans sharing compatible persistent state.

### Prefill plan

Consumes a block of prompt positions and establishes:

- cache contents;
- cache write position;
- last hidden/logit state needed for first generation token.

### TBT plan

Consumes one new token position and:

- reads the logical cache window;
- computes one new decoder step;
- writes one new K/V entry per layer;
- advances the ring;
- produces next-token logits.

The two plans must agree on:

- cache IDs;
- entry shape;
- byte layout;
- quantization;
- ring length;
- read/write offset convention;
- head ordering.

A disagreement here can produce fluent-looking garbage, which is one reason cache bugs are so deceptive.

---

# Part XVII — The Cache Manager Facts From Public HailoRT

Public HailoRT source gives several useful runtime truths without revealing the arithmetic compiler.

The current cache manager:

- associates cache inputs/outputs through `cache_id`;
- requires the key sets to match;
- tracks a global logical cache length;
- stores a read offset in entries;
- advances it modulo cache length;
- derives an entry's byte geometry from the layer's hardware feature shape;
- aligns/pads entry storage according to descriptor constraints;
- maintains shared backing buffers per cache ID.

This strongly supports modeling cache state as a real runtime resource rather than as ordinary transient tensors.

Suggested Aesir structure:

```text
CacheResource
  cache_id
  layer_id
  kind: K | V
  logical_entries
  logical_features
  device_entry_size
  device_padded_entry_size
  numerical_format
  read_offset
  write_offset
  backing_resource
  input_binding
  output_binding
```

Keep logical and physical sizes separate.

A 272-feature logical tensor that requires padding is not "272 bytes" simply because one field has that count.

---

# Part XVIII — Debugging Failure Classes

## Structural compiler failure

Symptoms:

- source operation unsupported;
- dimension mismatch;
- impossible shard plan;
- unresolved physical field.

Action:

Fail before hardware emission.

## Placement failure

Symptoms:

- resource conflict;
- local-memory overflow;
- impossible context partition;
- illegal cluster/subcluster assignment.

Action:

Return a placement diagnostic that names the exact IR objects and resource demand.

## Encoding failure

Symptoms:

- field out of range;
- unknown opcode/config value;
- CRC/checksum unresolved;
- impossible record extent.

Action:

Never substitute zero. Fail closed.

## Transport failure

Symptoms:

- mapping error;
- DMA launch error;
- timeout;
- malformed reply;
- missing/foreign completion;
- cache-sync failure.

Action:

Poison the owning session when required and preserve uncertain resources.

## Numerical failure

Symptoms:

- device executes but output differs from oracle;
- cosine acceptable but argmax wrong;
- drift grows with layers;
- only TBT fails while prefill passes.

Action:

Bisect the numerical ladder, not the transport stack.

## Runtime-contract failure

Symptoms:

- correct primitive math but wrong positions;
- cache entries mixed;
- prompt-length-dependent corruption;
- tokenization disagreement;
- large-vocabulary output reordered.

Action:

Inspect masks, RoPE, cache offsets, tokenizer IDs, output shard ordering, and sidecar/config values.

---
# Part XIX — Research Program for the Unknown Hailo Numerical Interface

## Research order matters

The remaining unknowns are coupled, but they should not be attacked all at once.

Use the following order because each stage constrains the next.

### Research lane A: public runtime and schema mining

Continuously diff the public HailoRT tree, especially:

```text
hailort/libhailort/hef.proto
common/include/context_switch_defs.h
hailort/libhailort/src/hef/
hailort/libhailort/src/core_op/resource_manager/
hailort/libhailort/src/vdma/
hailort/hrpc_protocol/rpc.proto
common/include/control_protocol.h
```

Questions:

- Which fields exist?
- Which are host metadata versus device-consumed payloads?
- Which fields changed between 5.3 and 5.4?
- Which values are enums with publicly defined meanings?
- Which payloads remain opaque?
- Which resource-manager paths expose sizing/alignment formulas?
- Which cache rules are enforced by the runtime?

Every useful fact should include:

```text
source URL
commit hash
affected release
license
exact concept extracted
what the fact does NOT prove
```

### Research lane B: kernel driver and UAPI

The driver is the best authority for host/device ownership and DMA mechanics.

Continue extracting:

- ioctl numbers and argument layouts;
- map/unmap rules;
- descriptor list construction constraints;
- channel counts/assignment semantics;
- cache-sync directions;
- interrupt completion semantics;
- connection lifecycle;
- failure/cleanup behavior.

Do not infer arithmetic-resource geometry from DMA descriptor capacity.

### Research lane C: patents

Use patents to generate **questions**, not bytes.

Examples:

- If a patent describes static configuration plus compact dynamic instructions, search public declarations for corresponding context/action families.
- If a patent describes memory windows, search for fields whose names and usage fit window selection.
- If it describes CRC-protected instruction streams, search public code for validation or size fields around program transfer.

Each patent lead should terminate in one of three states:

```text
corroborated by public interface
corroborated physically
unresolved
```

Never promote a patent-only numeric constant to program output.

### Research lane D: external experimental compiler

Use the open experimental Hailo-10H LLM compiler to build a checklist of observable behavior:

- graph shape expected by Hailo GenAI;
- prefill/TBT split;
- cache entry behavior;
- RoPE runtime input geometry;
- attention-mask preparation;
- output/lm_head sharding;
- tokenizer/config resource behavior;
- numerical failure cases.

Its DFC calls are not Aesir's backend. Its findings are questions and regression targets.

### Research lane E: bounded physical observations

Physical experiments should answer one question at a time.

Good physical question:

> Does this already-qualified grouped Mojo transport successfully complete one typed create/identify/destroy lifecycle on the exact installed 5.3 profile?

Bad physical question:

> What happens if we spray likely-looking CCWs at the chip until something works?

The latter destroys causality and creates unnecessary hardware risk.

---

## Reverse specification, not blind reverse engineering

The goal should be to build a written specification before building a general emitter.

For every newly discovered device-program field, create a table like:

| Field | Width | Domain | Source | Physical corroboration | Allowed values | Effect | Unknowns |
|---|---:|---|---|---|---|---|---|
| example | 16 | context config | public header | no | unknown | suspected offset | physical units unresolved |

Only fields with enough evidence should enter `PlacedIR` or `ContextIR`.

This creates a compiler whose assumptions are inspectable instead of buried in bit shifts.

---

# Part XX — Version Discipline

## Hailo 5.3 and 5.4 must not be blended casually

Volmarr's current physical evidence is anchored heavily to a **5.3.0** installed runtime/driver/firmware family.

Public Hailo software has moved into the **5.4.x** generation.

Aesir already performed a useful 5.3-to-5.4 public-interface delta and found that some program/container structures remained stable while other transport and direct-control details changed.

Therefore every hardware fact should carry a profile:

```text
HailoProfile
  board_type
  PCI identity
  kernel
  driver version
  driver build/source identity
  runtime version
  firmware version if observed
  public-source commit used for interface qualification
```

### Compatibility rule

Never do this:

```text
5.4 public declaration + 5.3 installed firmware + old clean-room offset
→ "probably compatible"
```

Instead classify:

```text
identical bytes across pinned public versions
compatible by explicitly tested behavior
version-specific
unknown
```

If the physical machine is later upgraded to 5.4, create a fresh device profile and rerun only the qualification necessary to establish equivalence. Do not silently inherit 5.3 physical claims.

---

# Part XXI — Clean-Room, Licensing, and Provenance Rules

## Preserve the current discipline

Aesir has intentionally separated facts from implementations. Keep that separation.

### For MIT/BSD/public code

It is lawful to study permissively licensed source, but Project Aesir has chosen a conservative architecture where outside implementations are not simply translated into Mojo.

For each research source:

1. read/record the license;
2. pin the commit;
3. record hashes where useful;
4. extract interface behavior in original prose;
5. write Aesir's implementation from the specification and project design;
6. use external tools only as isolated test oracles when allowed by the task contract.

### For GPL driver source

Driver/UAPI facts can inform interoperability research. Keep implementation boundaries clear and respect the license if any code is ever incorporated rather than merely studied.

### For proprietary DFC behavior

The DFC is not an allowed product dependency under Volmarr's fixed scope.

Do not:

- make users install it;
- require a separate compilation machine;
- turn model loading into a DFC workflow;
- claim Aesir support only for models someone else compiled.

The independent DFC-based research project remains useful as external experimental evidence. If a future research task ever uses proprietary tooling as an isolated oracle, that should require explicit owner authorization and remain outside Aesir's runtime/compiler dependency chain.

---

# Part XXII — Yrsa's Engineering Operating Protocol

## Session bootstrap

At the start of every Hailo engineering session, Yrsa should inspect, in this order:

```text
1. docs/HAILO10H_OWNER_NATIVE_SCOPE_2026-10-20.md
2. docs/HAILO10H_SOURCE_EXECUTION_PROGRESS.md
3. TODO.md
4. HAILO10H_ONLY_200_SLICE_ROADMAP.md
5. the newest Hailo-related commits on main
6. the active TASK_hailo10h_*.md contract
7. evidence/documentation for the immediately preceding capability
8. exact installed target profile before any physical run
```

Do not begin from an old roadmap merely because it has a large slice number.

### Before writing code

Answer these questions in writing:

```text
What exact capability is being added?
What does it explicitly NOT prove?
Which source files may change?
Which previous owners are reused rather than duplicated?
What host tests can prove before hardware?
What independent oracle checks the new bytes/math?
What is the one bounded physical action, if any?
What happens if cleanup is uncertain?
What evidence must be retained?
```

Then publish a task contract.

### During implementation

Prefer typed values over byte arrays.

Bad:

```text
List[UInt8] mysterious_config
```

Better:

```text
PlacedLinearOperation
SequencerAction
CacheResource
ProgramTargetArch
TransferGroup
```

Encoding should occur at the narrowest boundary possible.

### Before a physical run

Require:

- clean build of the exact consumer;
- host acceptance complete;
- independent byte/schema oracle complete;
- frozen executable hash;
- frozen target profile;
- explicit outer watchdog;
- no uncontracted side effects;
- one-shot rule understood;
- raw evidence destination prepared.

### After a physical run

Write the result in two sections:

```text
PROVEN
NOT PROVEN
```

This simple habit prevents accidental capability inflation.

---

# Part XXIII — Recommended Capability Ledger for the Finish Line

Aesir already has a detailed capability ledger. For the remaining numerical work, maintain a compact parallel matrix that makes the bridge visible.

| Capability | Host | Physical transport | Physical numerical | Full model |
|---|---|---|---|---|
| Source tensor ownership | ✅ | n/a | n/a | partial/broadening |
| Mathematical decoder IR | ✅ | n/a | n/a | broadening |
| Numerical policy IR | partial | n/a | ❌ | ❌ |
| Tile planning | partial | n/a | ❌ | ❌ |
| Physical placement | ❌ | n/a | ❌ | ❌ |
| Context record codecs | ✅ | partial | ❌ numerical | ❌ |
| Grouped control transport | ✅ | next gate | n/a | ❌ |
| Program payload staging | ✅ | partial | ❌ | ❌ |
| Program activation | ❌ | ❌ | ❌ | ❌ |
| First numerical primitive | design/research | transport prerequisites | ❌ | n/a |
| GEMM | mathematical only | prerequisites | ❌ | ❌ |
| RMSNorm | mathematical only | prerequisites | ❌ | ❌ |
| RoPE | mathematical only | prerequisites | ❌ | ❌ |
| Attention | mathematical only | prerequisites | ❌ | ❌ |
| MLP | mathematical only | prerequisites | ❌ | ❌ |
| One decoder layer | mathematical IR | prerequisites | ❌ | ❌ |
| Prefill | runtime behavior understood | prerequisites | ❌ native | ❌ native |
| TBT + KV cache | runtime behavior understood | prerequisites | ❌ native | ❌ native |
| Ordinary model end-to-end | source side strong | partial | ❌ | ❌ |

Update this table as facts become real.

---

# Part XXIV — Open Questions Ranked by Leverage

## Tier 1: blocks any native numerical operation

1. **Exact Hailo-10H arithmetic/configuration encoding.**
2. **Physical compute-resource geometry and legal placement values.**
3. **Static configuration versus LCU microprogram boundary.**
4. **Exact program activation/ready/completion sequence for an Aesir-generated numerical context.**
5. **Output/result buffer binding for that context.**

These deserve most research effort.

## Tier 2: blocks transformer-scale correctness

6. Exact precision/packing rules for matrix operations.
7. Accumulator/rounding/saturation behavior.
8. Cache physical format and format-conversion requirements.
9. Multi-context scheduling/resource reuse.
10. lm_head output sharding/merge policy.
11. RoPE and mask host/device division.
12. sensitive-operation precision policy for norm/softmax/gates.

## Tier 3: blocks broad model coverage

13. Remaining GGUF quantization variants.
14. More Safetensors dtype variants.
15. alternative normalization types.
16. non-SwiGLU activations.
17. MoE routing and expert placement.
18. unusual positional encodings.
19. very long context/window policies.
20. architecture-specific cache layouts.

Do not let Tier 3 breadth distract from Tier 1 silicon execution.

---

# Part XXV — A Concrete Finish-Line Campaign

This is a recommended campaign, not a claim that every step can be completed with currently known information.

## Campaign 1: close the grouped physical control gap

**Goal:** real CREATE → IDENTIFY → DESTROY through the new grouped Mojo owner.

**Exit condition:** exact typed replies, completion, cleanup, target profile, one bounded run.

## Campaign 2: generalize physically proven grouped exchange ownership

**Goal:** prove the transport primitive used later by program/data exchanges.

**Exit condition:** exact returned-count/completion/cache-sync/lifetime semantics observed physically.

## Campaign 3: program resource lifecycle

**Goal:** create, transfer, finalize, identify/readiness-check, destroy a structurally valid program/resource object without claiming arithmetic execution.

**Exit condition:** remote lifecycle proven, no leaked resources, exact payload identity.

## Campaign 4: numerical interface specification

**Goal:** close enough CCW/config/placement unknowns to describe one tiny operation completely before encoding it.

**Exit condition:** a human-readable spec where every emitted field has a source and a known meaning.

## Campaign 5: first numerical operation

**Goal:** one tiny, safe, deterministic operation.

**Exit condition:** physical output matches independent expected output and repeated fresh sessions reproduce it.

## Campaign 6: matrix contraction

**Goal:** establish the engine needed for transformer linear layers.

**Exit condition:** exact/specified-tolerance results over a matrix corpus spanning tile boundaries.

## Campaign 7: transformer primitive suite

**Goal:** RMSNorm, RoPE, attention score/softmax/value, gated MLP.

**Exit condition:** each operation independently verified and composable.

## Campaign 8: one decoder block

**Goal:** source-bound ordinary weights drive one complete block.

**Exit condition:** layer output matches reference within declared tolerances.

## Campaign 9: prefill

**Goal:** several decoder layers or a tiny full model process a fixed prompt.

**Exit condition:** final logits and next token verified.

## Campaign 10: cache/TBT

**Goal:** persistent cache plus repeated token generation.

**Exit condition:** explicit cache-offset tests, wrap tests, and multi-token numerical agreement.

## Campaign 11: ordinary model load

**Goal:** user points Aesir at an ordinary GGUF/Safetensors model with no external compilation step.

**Exit condition:** model internally compiles, runs on Hailo-10H, and returns coherent verified generation.

## Campaign 12: broadening

**Goal:** turn the first path into architecture/format coverage rather than a demo special case.

**Exit condition:** capability matrix, explicit refusals for truly unimplemented cases, ongoing expansion toward the owner's 100% target.

---

# Part XXVI — What Not to Do

These shortcuts would create impressive demos while moving away from the actual project target.

## Do not hide the vendor compiler behind Aesir

Calling DFC from Mojo is still requiring DFC.

## Do not ship a tiny catalog of known compatible HEFs as "native support"

That already has a working historical route and is not the owner target.

## Do not run fallback LLM layers on the Pi CPU

Host orchestration is allowed. CPU LLM inference is not the intended execution route.

## Do not invent unknown CCWs from patent diagrams

A plausible instruction is still an unknown instruction.

## Do not equate model size with fit

Fit depends on placement, context strategy, cache, intermediate tensors, numerical formats, and resource reuse.

## Do not claim hardware success from a mapped buffer

Mapping proves mapping.

## Do not claim numerical success from program acceptance

Acceptance proves acceptance.

## Do not accept coherent text as the first numerical gate

Language models can produce plausible output while carrying serious numerical errors.

## Do not let testing infrastructure become production dependency

Python, C++, protobuf, public libraries, or external model frameworks can serve as isolated oracles if the task allows. Production ownership stays in Aesir's intended architecture.

---

# Part XXVII — Yrsa Study Sequence

Yrsa should not read the repository alphabetically. Use this sequence.

## Pass 1: mission and truth boundaries

Read:

```text
docs/HAILO10H_OWNER_NATIVE_SCOPE_2026-10-20.md
docs/HAILO10H_SOURCE_EXECUTION_PROGRESS.md
TODO.md
CAPABILITY_LEDGER.md relevant Hailo tail
```

Goal: know what counts as completion.

## Pass 2: current physical transport

Read:

```text
docs/HAILO10H_MOJO_DRIVER_OWNER.md
docs/HAILO10H_MOJO_SESSION_LIFECYCLE.md
docs/HAILO10H_DMA_PROTOCOL_CORRECTIONS.md
docs/HAILO10H_MOJO_SEALED_TRANSFER_PIN.md
docs/HAILO10H_MOJO_SESSION_TRANSFER_PIN_PROBE.md
docs/HAILO10H_MOJO_GROUP_CONTROL_RPC.md
docs/HAILO10H_MOJO_GROUP_DEVICE_RPC.md
TASK_hailo10h_grouped_device_probe.md
```

Goal: understand the real current physical frontier.

## Pass 3: source compiler

Read the owned source/compiler docs for:

- GGUF;
- Safetensors;
- source configuration;
- shard collection;
- typed decoder;
- projection binding;
- rotary;
- activation;
- bias;
- cache/session;
- windows;
- scaling;
- dynamic graph;
- tied-output identity.

Goal: understand that the source side is not the primary blocker anymore.

## Pass 4: program structure and control

Read:

```text
docs/HAILO10H_ORIGINAL_PROGRAM_STRUCTURE.md
docs/HAILO10H_PROGRAM_INTEGRITY_FACTS.md
docs/HAILO10H_PROGRAM_TARGET_AND_LCU_BOUNDARY_2026-10-22.md
docs/HAILO10H_SEQUENCER_INTERFACE_2026-10-23.md
docs/HAILO10H_MOJO_SEQUENCER_ACTIONS.md
docs/HAILO10H_MOJO_PROGRAM_PAYLOAD.md
```

Goal: separate known envelope/control facts from unknown numerical fields.

## Pass 5: clean-room transport and configuration research

Read:

```text
docs/plunder/HAILO_PCIE_TRANSPORT_GUIDE.md
docs/plunder/HAILO_COMMAND_QUEUE.md
docs/plunder/HAILO_HEF_CONTAINER_GUIDE.md
docs/plunder/HAILO_CONFIG_SURFACE.md
docs/HAILO10H_NUMERICAL_ENCODING_LEADS_2026-10-20.md
docs/HAILO10H_PUBLIC_ENCODING_DELTA_2026-10-20.md
docs/HAILO10H_WINDOW_CONFIGURATION_LEAD_2026-10-23.md
```

Goal: know exactly where the public evidence stops.

## Pass 6: external LLM behavior research

Study the MIT external project:

```text
https://github.com/l-nmch/hailo-10h-llm-compiler
```

Prioritize its findings on:

- missing lm_head;
- last-position output;
- RoPE input widths;
- attention-mask tiling;
- KV-cache layout;
- tokenizer/BOS behavior;
- quantization recipe;
- large-vocabulary lm_head sharding;
- large-checkpoint numerical drift.

Goal: create regression hypotheses for Aesir's native implementation, not import its DFC workflow.

## Pass 7: public HailoRT master

Read current public runtime source around:

- HEF metadata;
- cache manager;
- VDMA resource manager;
- GenAI LLM server;
- hRPC schemas;
- context switch definitions.

Goal: understand the latest public runtime contract and compare it against the installed 5.3 profile before using any changed field physically.

---

# Part XXVIII — Quick Reference: Important Known Constants and Boundaries

These values are useful study anchors. They are not all interchangeable across versions or namespaces.

| Item | Known value / observation | Evidence class |
|---|---|---|
| PCI vendor ID | `0x1e60` | public + physical |
| Hailo-10H PCI device ID in Aesir study | `0x45C4` | public + physical |
| Physical board type observed | H10H board type 2 | physical Aesir evidence |
| Physical PCIe DMA type observed | 0 | physical Aesir evidence |
| Physical DMA engines observed | 1 | physical Aesir evidence |
| Installed Hailo stack used for many physical tests | 5.3.0 family | physical Aesir evidence |
| Public version delta studied | 5.3.0 → 5.4.0 | public interface study |
| Host page size in recorded Pi session | 16384 | physical Aesir evidence |
| Observed maximum descriptor page | 4096 | physical Aesir evidence |
| Session descriptor page in recorded owner | 512 | physical Aesir evidence |
| Group control store size | 2068 bytes | qualified Aesir transport design |
| Group header/body spans | 20 + 2048 bytes | qualified Aesir transport design |
| Program/container v3 outer header | 56 bytes | public format fact |
| Program-side HAILO1XH enum | 103 | public program namespace |
| Runtime Hailo-10H architecture enum | 6 | separate public runtime namespace |
| Sequencer trigger action | 1 | public packed context record |
| Sequencer done action | 17 | public packed context record |
| LCU enable action | 4 | public packed context record |
| LCU disable action | 5 | public packed context record |
| LCU batch switch action | 36 | public packed context record |
| Typed grouped device lifecycle used by current Aesir host owner | create 20 / identify 22 / destroy 21 | current project RPC contract |

When using this table, always return to the cited project/source document before writing physical code.

---

# Part XXIX — Glossary

**A8W4**  
Eight-bit activations with four-bit weights. A common Hailo LLM deployment pattern, not a universal requirement for every operation.

**APU**  
A Hailo resource name exposed in sequencer configuration fields. Exact Hailo-10H physical mapping must be qualified before assigning values.

**CCW**  
Configuration/control-word payload associated with compiled hardware configuration. Public runtime structures expose containers and actions around CCW data, but the decisive arithmetic encoding remains a central unknown for native Aesir generation.

**Context**  
A hardware-execution configuration/schedule unit inside a compiled Hailo network group.

**DFC**  
Hailo Dataflow Compiler. Valuable as the vendor compiler and as a source of external research observations, but prohibited as an Aesir user prerequisite under the fixed owner scope.

**DMA / VDMA**  
Bulk host/device movement through descriptor-backed channels. Transport is not computation.

**GGUF**  
A common local-model format used by llama.cpp-family ecosystems. Aesir has extensive native GGUF source work.

**GQA**  
Grouped-query attention. Q-head count exceeds K/V-head count; important for cache and RoPE layout.

**HAILBRÚ**  
Project Aesir's Mojo-side Hailo transport/control body of work.

**HEF**  
Hailo Executable Format. Vendor compiled-container format. Aesir studies its public structure to learn required functional responsibilities but the final owner target does not require users to provide precompiled HEFs.

**hRPC**  
Hailo RPC protocol used by the host/runtime stack for resource and control messages.

**IR**  
Intermediate representation. A compiler layer between source model semantics and final encoded device bytes.

**KV cache**  
Persistent key/value state for autoregressive attention. On Hailo, public runtime code treats it as managed ring-like resources with IDs, entry sizes, and rotating offsets.

**LCU**  
Layer-control unit terminology appearing in Hailo architecture/public control material. It is associated with dynamic per-layer/context control. Exact H10H instruction semantics remain partly unknown.

**lm_head**  
The final hidden-to-vocabulary projection. Large vocabularies may need physical sharding.

**NPU**  
Neural processing unit. Hailo-10H uses a structure-driven dataflow approach rather than exposing a GPU-like general instruction model to applications.

**Prefill**  
Prompt-processing phase. Processes multiple prompt tokens and initializes cache state.

**RoPE**  
Rotary positional embeddings. Position convention and Q/K head geometry must match runtime and compiler expectations exactly.

**Safetensors**  
A tensor storage format widely used by Hugging Face checkpoints. Aesir has native ownership/index work for ordinary Safetensors sources.

**SMIÐR**  
Aesir's compiler/device-generation domain for creating Hailo-side configuration/program structures.

**TBT**  
Token-by-token autoregressive decode phase after prefill.

---

# Part XXX — Primary Source Map

## Project Aesir

Repository:

```text
https://github.com/hrabanazviking/RuneForgeAI-Project-Aesir
```

High-priority internal documents:

```text
docs/HAILO10H_OWNER_NATIVE_SCOPE_2026-10-20.md
docs/HAILO10H_SOURCE_EXECUTION_PROGRESS.md
aesir_engine/HAILO10H.md
docs/HAILO10H_MOJO_OWNED_GGUF_COMPILER.md
docs/HAILO10H_MOJO_SESSION_TRANSFER_PIN_PROBE.md
docs/HAILO10H_MOJO_GROUP_CONTROL_RPC.md
docs/HAILO10H_MOJO_GROUP_DEVICE_RPC.md
docs/HAILO10H_ORIGINAL_PROGRAM_STRUCTURE.md
docs/HAILO10H_PROGRAM_INTEGRITY_FACTS.md
docs/HAILO10H_PROGRAM_TARGET_AND_LCU_BOUNDARY_2026-10-22.md
docs/HAILO10H_SEQUENCER_INTERFACE_2026-10-23.md
docs/HAILO10H_MOJO_SEQUENCER_ACTIONS.md
docs/HAILO10H_MOJO_PROGRAM_PAYLOAD.md
docs/HAILO10H_NUMERICAL_ENCODING_LEADS_2026-10-20.md
docs/HAILO10H_PUBLIC_ENCODING_DELTA_2026-10-20.md
docs/HAILO10H_WINDOW_CONFIGURATION_LEAD_2026-10-23.md
docs/plunder/HAILO_PCIE_TRANSPORT_GUIDE.md
docs/plunder/HAILO_COMMAND_QUEUE.md
docs/plunder/HAILO_HEF_CONTAINER_GUIDE.md
docs/plunder/HAILO_CONFIG_SURFACE.md
TODO.md
CAPABILITY_LEDGER.md
```

## Hailo public runtime source

```text
https://github.com/hailo-ai/hailort
```

Important areas:

```text
hailort/libhailort/hef.proto
hailort/libhailort/src/hef/
hailort/libhailort/src/core_op/resource_manager/cache_manager.cpp
hailort/libhailort/src/vdma/
hailort/libhailort/src/genai/
hailort/hailort_server/genai/
hailort/hrpc_protocol/rpc.proto
common/include/context_switch_defs.h
common/include/control_protocol.h
```

Pin a commit before deriving version-sensitive facts.

## Hailo public model information

Hailo's current Model Zoo and generative-AI material provide useful evidence for:

- currently supported/public model families;
- context sizes;
- published quantization schemes;
- throughput baselines;
- software-stack generation.

Use the live current documentation rather than the older Aesir `Complete_Hailo_10_NPU_Reference_Guide.md` as the version authority.

## Independent Hailo-10H LLM compiler research

```text
https://github.com/l-nmch/hailo-10h-llm-compiler
```

Especially:

```text
docs/status.md
docs/findings/index.md
docs/findings/tbt-cache-read.md
docs/findings/quantization-recipe.md
docs/findings/tokenizer-bos-mismatch.md
docs/findings/rope-input-widths.md
docs/findings/attention-mask-broadcast.md
docs/findings/kv-cache-config-key.md
docs/findings/large-vocab-lm-head-sharding.md
```

Treat it as EXTERNAL EXPERIMENTAL evidence.

## Hailo patents already useful to Aesir research

```text
US11514291B2
US11237894B1
US11354563B2
```

Use these as architectural research leads only.

---

# Part XXXI — The Finish-Line Definition

Project Aesir has crossed the finish line for the first native Hailo model only when all of the following are true at the same time:

- [ ] The input is an ordinary, unmodified supported source-model file such as GGUF or Safetensors.
- [ ] The user did not run Hailo DFC or provide a vendor-precompiled model.
- [ ] Aesir owns source parsing and immutable source identity.
- [ ] Aesir owns architecture semantics and mathematical lowering.
- [ ] Aesir owns numerical-policy selection and device representation conversion.
- [ ] Aesir owns tiling and physical placement for the target Hailo-10H profile.
- [ ] Aesir emits the required hardware configuration/program bytes from qualified facts.
- [ ] Aesir owns program/resource transport and activation.
- [ ] The Hailo-10H physically executes the decoder computation.
- [ ] No CPU/CUDA/cloud path performs the model's LLM forward pass as fallback.
- [ ] Prefill is numerically verified.
- [ ] TBT is numerically verified.
- [ ] KV-cache behavior is verified across multiple tokens and wrap/boundary cases.
- [ ] Final logits or token choices meet declared numerical acceptance criteria.
- [ ] Cleanup/recovery behavior is qualified.
- [ ] The exact device/runtime/compiler/source identities are reported.
- [ ] The capability claim states the formats/architectures/operators actually implemented without redefining the owner's broader target downward.

For **broad** completion, repeat that path across the intended model-format and architecture matrix until ordinary compatible models no longer require hand-authored per-model compiler surgery.

---

# Final Message to Yrsa

The project is not at the beginning.

It already has a working vendor-runtime proof that this physical Hailo-10H can execute an LLM. It has a deep Mojo source-model compiler, unusually strong ownership/provenance machinery, extensive transformer semantic lowering, and a rapidly maturing native transport path that reaches the real device.

The remaining gap is narrower than "support Hailo" but deeper than a normal backend integration.

You must discover and formalize the Hailo-10H's executable numerical configuration sufficiently to connect two existing bodies of work:

```text
Aesir source-model semantics
          ↓
     THE MISSING BRIDGE
          ↓
Aesir HAILBRÚ physical transport
```

Do not solve that bridge by weakening the target.

Do not call DFC behind the curtain.

Do not substitute a catalog.

Do not move LLM math to the Pi.

Do not promote metadata into imaginary machine code.

Instead, close the unknowns one measurable fact at a time. Keep the typed IR richer than the byte format. Preserve source identity through every lowering stage. Require every physical value to have provenance. Treat failures as information. Use the working HailoRT path and external compiler research as behavioral oracles, not dependencies. Verify primitive numerics before transformer numerics, prefill before TBT, and cache layout before judging language quality.

The upper river already reaches the edge of the canyon. The lower river already reaches upward from the Hailo-10H. The job is to engineer the bridge between them.

When that bridge carries the first ordinary model from source bytes to verified Hailo-10H tokens, Project Aesir will have done something substantially different from merely wrapping a vendor runtime.

**That is the finish line.**

---

# Snapshot Notes

This book was assembled on **2026-10-24** from:

- the live Project Aesir `main` branch and its Hailo evidence/docs;
- current public Hailo sources and official documentation available at research time;
- the public HailoRT 5.3/5.4 interface lineage already pinned by Aesir;
- public Hailo patent material;
- the MIT-licensed independent Hailo-10H LLM compiler research project;
- the physical Hailo-10H evidence already committed by Project Aesir.

Because the Hailo software stack is active, **version-sensitive fields must be rechecked against current sources before future physical code is written**. This book is a technical map and handoff corpus, not a substitute for fresh evidence at the moment of a new device write.
