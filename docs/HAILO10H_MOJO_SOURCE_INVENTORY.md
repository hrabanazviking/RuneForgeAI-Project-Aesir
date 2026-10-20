# Source tensor inventory for the Mojo compiler

Date: 2026-10-19. Contract: `TASK_hailo10h_source_compiler_plan.md`, first
input-descriptor portion of acceptance 1. No graph lowering or execution yet.

`smidr/source_inventory.mojo` reads source metadata/tensor descriptors through
the existing PackedGGUF file/range owner, then projects them into original
owned `SourceTensorInventory` / `SourceTensorBinding` values. It records the
architecture string, source/data sizes, exact absolute file offsets, source
quantization kinds, dimensions and total source tensor bytes. Compiler-boundary
checks repeat extent validity and use checked accumulation. No mapped pointer
escapes. The tool is `smidr/tools/source_inventory.mojo`.

The inventory does not consult CPU/CUDA backend registry allowlists, allocate
model activations/KV/device tensors, dequantize weights or invoke a forward.
Unknown architecture text can therefore be inventoried without a false support
claim. Source bytes remain unchanged. Dictionary iteration order is unspecified;
this inspection output is not a canonical executable program or execution order.

A descriptor snapshot is not an immutable weight identity. Production output
explicitly records `source_fingerprint_verified:false`, `execution_tested:false`
and `executable_program:false`. Future weight binding/upload must establish
source identity and retain/revalidate the actual source owner. Source tensor
bytes are not a Hailo resident-memory estimate or hardware fit result.

## Parser correction

The reused GGUF string reader previously appended NUL and used an unsafe C
string constructor. That could truncate a length-prefixed metadata/tensor name
and trusted its UTF-8. It now copies exactly the declared bytes into Mojo's
validating `String(from_utf8=...)`. Embedded NULs remain part of the value;
malformed UTF-8 raises. File-path NUL rejection remains independently tested.
No model bytes or encoding are rewritten.

Interface facts: the MIT-licensed GGUF specification at ggml commit
`a05c9922613c6a2230dbb1d0de679519ecafb4f0` describes length-prefixed UTF-8 text:
[GGUF specification](https://github.com/ggml-org/ggml/blob/a05c9922613c6a2230dbb1d0de679519ecafb4f0/docs/gguf.md).
Specification SHA-256:
`1dead27b6a522709f0127d194e58c21dbbbf00ba1c64fe37c54d1a9048b05020`.
Mojo's documented validating constructor:
[String API](https://mojolang.org/docs/std/collections/string/string/String/).
No ggml implementation, headers or library are copied, translated or linked.

## Verification

Six methods pass over 16 independent tiny GGUF fixture runs (eight accepted,
eight refused). The fixture writer uses Python struct packing, independent of
the native reader, and checks exact descriptor JSON and source SHA-256 before/
after every run. Cases cover F16/F32/BF16 and the reader's K-quant layouts;
novel architecture text; Unicode/quotes/controls/embedded NUL; malformed UTF-8;
truncation, overlap, duplicate names, missing facts and unknown tensor layouts.
A strace run confirms read-only source mapping/cleanup and no Hailo, CUDA or
HailoRT access. No fixture runs an LLM forward.

The existing parser state/malformed-file/GGML-type regression passes using an
explicit zero-tensor fixture in a private work directory. The header fuzz
regression passes too; its removed InlineArray spelling was updated to the
current public Array type. The initial legacy compile error is retained.
Initial inventory-test expectation reached row alignment before its intended
unknown-type check; the final fixture is block aligned and tests the intended
unknown type directly. Evidence: `evidence/source-inventory-2026-10-19`,
including all fixture fingerprints/stdout/stderr and the read-only trace.

## Remaining importer and compiler work

This slice inherits PackedGGUF's present GGUF-v3 vector/matrix layout subset
(F32, F16, BF16, Q4_K, Q5_K, Q6_K). Other types/ranks, formats and sharded inputs
remain named importer work; that subset is not a Hailo hardware or product
support boundary. The owner target remains source models that fit the hardware.

Next: bind source tensors to semantic operations and checked shapes/lifetimes,
carry unresolved numeric/layout/backend facts, establish actual program/context
encoding and activation, then prove numerical operations on Hailo-10H. Existing
COMPUTE_UNKNOWN and host vector manifests remain non-executable. Native device
RPC is verified separately; complete source-model compilation is still missing.
