# Original Mojo public context-action codec

Date: 2026-10-19. Contract: `TASK_hailo10h_context_actions.md`.
Interface facts were published first in `HAILO10H_PUBLIC_CONTEXT_ACTIONS.md`.

## Implemented boundary

`smidr/context_actions.mojo` encodes/decodes owned `ContextAction` values for
four corroborated public action records. The native inspector consumes these
records without a device/syscall import in the codec. It emits both
`device_access:false` and `numerical_program:false`.

The tagged value's `values` list has the following explicit field order:

| Kind | Fields | Total encoded bytes, including header |
|---|---|---|
| 0, configuration descriptor fetch | count, engine, channel | 8 |
| 3, default LCU enable | cluster, LCU, network | 7 |
| 27, CCW burst fetch | burst count, configuration stream | 8 |
| 35, typed write | address, type, data, shift, mask, network | 20 |

Header timestamps retain every unsigned 32-bit value. All fields are checked
before narrowing. Channel and LCU IDs are packed only within the public field
widths; these widths are not physical resource counts. Typed-write type must
be general or batch. The shift is retained as an unsigned byte without
claiming register semantics. Zero counts/addresses are accepted as interface
values, never asserted to be executable or safe device requests.

The decoder requires an exact complete extent. Unsupported action IDs,
truncation, trailing data, unknown write types and reserved LCU bit 7 refuse.
The inspector bounds hex/argument input before allocating field data. Decoded
values and encoded bytes own their storage independently of their input.

## Independent verification

Build using Mojo 1.1.0 and a C++20 compiler. The C++ oracle includes the pinned
public header supplied outside Git; no vendor source/header is shipped here:

```sh
MODULAR_CACHE_DIR=../mojo-cache mojo build -I . -I aesir_engine smidr/tools/context_actions.mojo -o ../context-actions
MODULAR_CACHE_DIR=../mojo-cache mojo build -I . -I aesir_engine tests/hailo_context_action_ownership.mojo -o ../context-action-ownership
g++ -std=c++20 -Wall -Wextra -Werror -I "$AESIR_CONTEXT_INCLUDE" tests/hailo_context_action_oracle.cpp -o ../context-action-oracle
python3 tests/test_hailo_context_actions.py --binary ../context-actions --oracle ../context-action-oracle --ownership ../context-action-ownership --strace /usr/bin/strace --evidence docs/evidence/context-actions-2026-10-19
```

Seven methods pass, **244 native child calls**: 44 C++ object-byte vectors,
44 Mojo encodes, 44 Mojo decodes, 109 Mojo refusals, one C++ layout query, one
native ownership check and one syscall-traced inspector. All 44 full records
match both the independently written Python struct oracle and actual C++
header-defined object bytes, including zero/max/asymmetric values and seeded
vectors. The layout query checks enum values, five-byte header and timestamp
offset, all four body sizes and all six typed-write field offsets.

Refusals cover every byte truncation, trailing bytes, reserved/unknown fields,
unsupported kinds, missing/extra fields, negative or overflowing widths and
malformed/excessive hex. The ownership test mutates source fields and encoded
input bytes independently and confirms retained decoded/canonical values.
The syscall trace contains no Hailo node, HailoRT or CUDA access. Both final
Mojo builds and the C++ oracle build are warning-free. Initial passing runs and
pre-cleanup compiler warnings are retained. Evidence directory:
`docs/evidence/context-actions-2026-10-19/`.

## Dependencies and open execution gates

Header provenance records hashes for ten public include dependencies. Hailo
headers are MIT-licensed. The transitive md5 header's public-domain/permissive
notice by Alexander Peslyak was read; no MD5 implementation is linked or used.
The test oracle reads type/macro definitions only. Production code is original
Mojo from interface facts, not copied or translated vendor implementation.

This primitive does not create CCWs, place hardware resources, configure an
LCU, upload/activate a context, or execute arithmetic. Its bytes are never
submitted by the device RPC tool. The context/control and numerical-CCW
boundaries remain distinct. The documented host hRPC class has no established
raw-context upload method; sending these bytes on a guessed action is invalid.
Continue public upload/activation and CCW/register study plus source operation
lowering toward the unchanged source-model/Hailo goal. No vendor model or
compiled-container bytes were opened, repackaged or substituted.
