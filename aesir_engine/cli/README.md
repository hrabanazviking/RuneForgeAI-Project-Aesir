# Native CLI ownership

`commands.mojo` dispatches supported commands and rejects unfinished surfaces.
`hardware.mojo` presents observed hardware and checked model plans through the
engine facade. `cuda_chat.mojo` owns CLI options, prompt input and durable
transcripts; core sessions own generation and device memory. Loader owns the
pinned Hugging Face download. CLI must not implement transformer arithmetic.
`quantization_tuning_storage.mojo` owns opt-in locked atomic persistence for
the core tuner's versioned cache codec; it does not choose kernels or measure
them.
`storage.mojo` owns the restart-safe catalog and immutable SHA-256 blob store.
It hashes the exact staged inode, deduplicates without replacement, and exposes
full verification. Pinned pull registration uses the same measured transaction;
authenticated/resumable transfer and garbage collection remain separate.

See `INTERFACE.md` and `docs/NATIVE_RUNTIME.md` for supported commands and limits.
Legacy model-store and service command names are not operational merely because
their parser exists.
