# Native CLI ownership

`commands.mojo` dispatches supported commands and rejects unfinished surfaces.
`hardware.mojo` presents observed hardware and checked model plans through the
engine facade. `cuda_chat.mojo` owns CLI options, prompt input and durable
transcripts; core sessions own generation and device memory. Loader owns the
pinned Hugging Face download. CLI must not implement transformer arithmetic.

See `INTERFACE.md` and `docs/NATIVE_RUNTIME.md` for supported commands and limits.
Legacy model-store and service command names are not operational merely because
their parser exists.
