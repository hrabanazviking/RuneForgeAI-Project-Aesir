# Mojo integrated-device framing — verified transport primitive

Completed 2026-10-19 under `TASK_hailo10h_hrpc_framing.md` and the fixed
Mojo/source-model objective. This advances an alternate transport path beyond
the historical raw firmware mailbox experiment.

`hailbru/hrpc_frame.mojo` independently implements the pinned host envelope.
The real native consumer `smidr/tools/hrpc_frame.mojo` decodes recorded hex
frames, preserves opaque payload/status/IDs, and emits a canonical logical
packet. It never opens a device, loads a model or reports a computation.

## Verification

```sh
mojo build -I . smidr/tools/hrpc_frame.mojo -o work/hrpc-frame
python3 tests/test_hailo_hrpc_frame.py --binary work/hrpc-frame -v
mojo build -I . tests/hailo_hrpc_frame_api.mojo -o work/hrpc-frame-api
work/hrpc-frame-api
```

Both native builds pass on the installed Mojo 1.1.0 Pi environment. Eight
independent Python test methods pass, covering fixed literal/`struct` wire
parity, body boundaries 0..2048, all-ones UInt32 fields, nonzero remote status,
every truncated header length, bad magic, length disagreement, oversize
declarations, exact padded-buffer sizing and invalid hex/CLI arguments.
Thirty-two seeded payload/field cases additionally match the independent
serializer.

Direct Mojo API checks pass for oversized outbound refusal and copied body
ownership: mutating input wire/body or the decoded owner does not alter a
different frame owner. Explicit padded mode strips untrusted padding from the
logical body; ordinary packet mode rejects extra bytes.

## Meaning for the fixed target

The official v5.3.0 source routes device identification through typed RPC over
PCIe sessions, a distinct interface from the failed raw mailbox. This codec
is a working Mojo building block for that interface. It does not certify an
independent device round-trip, executable program generation, source-model
compilation or LLM inference.

Next: independently map the PCIe session/request lifecycle, then prove a
bounded read-only device round-trip through the owned Mojo path. Continue
the source compiler's operation/configuration work where dependencies are
genuinely independent. The product target stays unchanged.

Machine-readable hashes and raw passing output:
[receipt](evidence/mojo-hrpc-framing-2026-10-19/receipt.json),
[wire tests](evidence/mojo-hrpc-framing-2026-10-19/wire-tests.txt),
[API tests](evidence/mojo-hrpc-framing-2026-10-19/api-tests.txt).
