# Pointing Voxta at Aesir (and back)

Aesir's native serve runs beside Ollama; nothing about Ollama changes.

## What is running
- Unit: aesir-gate.service (machine-level systemd, fenced MemoryHigh=48G / MemoryMax=64G)
- Binary: /home/volmarr/aesir-q35-7/.aesir/aesir (branch yrsa/q35-7, Q35-7 stage 1+2;
  after the coordinator merges yrsa/q35-7 into yrsa/hip-serve, restart the gate from
  /home/volmarr/aesir-hipserve/.aesir/aesir — same source, same command below with the
  two paths swapped)
- Model (PRIMARY, since the Q35-7 swap 2026-11-14): the 27B heretic GGUF
  /mnt/vault/models/gguf/Qwen3.8-27B-Ultimate-Heretic-Uncn-Turbo-Brilli-50x-AGI-NEO-Q8_0.gguf
  (sha256 1fca6eefc37607b5ab458f9a76815b36aeb38cf21ac36c49fdc0ab4eb186f08e),
  profile qwen35, variant qwen35-27B, backend cpu, Q8_0 RESIDENT load
  (weight_load_mode=q8_0_resident), context 4096, max_tokens 512, timeout 900 s.
  Serve peak ~31.3 GB RSS class; expect ~1.5-1.8 tok/s end to end.
- Address: http://127.0.0.1:18434  (loopback only)
- Auth: bearer key required; the key text is in /home/volmarr/.config/aesir/service.key
- Endpoints Voxta uses: POST /v1/chat/completions (streamed and plain both proven 2026-11-14)
- Health: GET /health (with the same bearer key) reports profile qwen35,
  model_variant qwen35-27B, backend cpu, weight_load_mode q8_0_resident,
  session_residency true, exact_prefix_reuse true (snapshot-based detail)

## Fallback: llama3-3b (the pre-swap gate)
- Model: llama3-3b:latest (Llama-3.2-3B-Instruct Q4_K_M), backend hip (Radeon 8060S),
  fenced MemoryHigh=24G / MemoryMax=32G, context 8192, max_tokens 512.
- The exact pre-swap configuration is backed up at
  hidden_files/hip-serve/aesir-gate-llama3-3b-config-backup-q35-7.txt
- Rollback (exact steps):
  1. sudo systemctl stop aesir-gate.service
  2. sudo systemd-run --unit=aesir-gate -p User=volmarr -p MemoryHigh=24G -p MemoryMax=32G -p WorkingDirectory=/home/volmarr/aesir-hipserve /bin/bash -c 'export LD_LIBRARY_PATH=.pixi/envs/default/lib:.aesir/shims; exec ./.aesir/aesir serve llama3-3b:latest --accel hip --api-key-file /home/volmarr/.config/aesir/service.key --context 8192 --max-tokens 512 --port 18434 > hidden_files/hip-serve/serve-bench.log 2>&1'
  3. In Voxta, set the Aesir service's Model back to llama3-3b:latest (see below).

## Switch Voxta to Aesir
1. In Voxta: Services -> add a NEW service with the "OpenAI Compatible" module.
   Name it: Aesir
   URL: http://127.0.0.1:18434
   API key: the contents of /home/volmarr/.config/aesir/service.key
   Model: /mnt/vault/models/gguf/Qwen3.8-27B-Ultimate-Heretic-Uncn-Turbo-Brilli-50x-AGI-NEO-Q8_0.gguf
   (for the llama3-3b fallback configuration, Model: llama3-3b:latest instead)
   (Adding a new service keeps the Ollama service untouched, so switching back is one step.)
2. Configuration sets -> Default -> Text Generation role -> select the Aesir service.
3. Chat as usual. Turn 2+ of a chat reuses the cached prefix (system + history head);
   responses carry usage.reused_prompt_tokens if you want to watch it work.

## Switch back to Ollama
1. Configuration sets -> Default -> Text Generation role -> select the Ollama service
   (http://127.0.0.1:11434). Nothing else changes.

## Context note
- The 27B primary runs at context 4096 (the Q35-4b/Q35-7 proven configuration);
  a Voxta chat whose resent history exceeds it is refused honestly, not truncated.
- The llama profile validates context within 2..8192 tokens (engine rule, found
  2026-11-14 when 16384 was refused at admission). The serve therefore runs at
  8192 - plenty for a first test chat; a long Voxta chat can exceed it.

# Start / stop the Aesir serve
- Stop:  sudo systemctl stop aesir-gate.service
- Start (27B primary, Q35-7): sudo systemd-run --unit=aesir-gate -p User=volmarr -p MemoryHigh=48G -p MemoryMax=64G -p WorkingDirectory=/home/volmarr/aesir-q35-7 /bin/bash -c 'export LD_LIBRARY_PATH=/home/volmarr/aesir-q35-7/hidden_files/hip-serve/shims; exec ./.aesir/aesir serve /mnt/vault/models/gguf/Qwen3.8-27B-Ultimate-Heretic-Uncn-Turbo-Brilli-50x-AGI-NEO-Q8_0.gguf --accel cpu --profile qwen35 --qwen35-resident --api-key-file /home/volmarr/.config/aesir/service.key --context 4096 --max-tokens 512 --timeout-ms 900000 --port 18434 > hidden_files/qwen35-adapter/q35-7-gate-serve.log 2>&1'
- Start (llama3-3b fallback): the rollback command in the Fallback section above.
