# Pointing Voxta at Aesir (and back)

Aesir's native serve runs beside Ollama; nothing about Ollama changes.

## What is running
- Unit: aesir-gate.service (machine-level systemd, fenced MemoryHigh=24G / MemoryMax=32G)
- Binary: /home/volmarr/aesir-hipserve/.aesir/aesir (branch yrsa/hip-serve)
- Model: llama3-3b:latest (Llama-3.2-3B-Instruct Q4_K_M), backend hip (Radeon 8060S)
- Address: http://127.0.0.1:18434  (loopback only)
- Auth: bearer key required; the key text is in /home/volmarr/.config/aesir/service.key
- Endpoints Voxta uses: POST /v1/chat/completions (streamed and plain both proven 2026-11-14)
- Health: GET /health (with the same bearer key) reports backend hip, exact_prefix_reuse true

## Switch Voxta to Aesir
1. In Voxta: Services -> add a NEW service with the "OpenAI Compatible" module.
   Name it: Aesir
   URL: http://127.0.0.1:18434
   API key: the contents of /home/volmarr/.config/aesir/service.key
   Model: llama3-3b:latest
   (Adding a new service keeps the Ollama service untouched, so switching back is one step.)
2. Configuration sets -> Default -> Text Generation role -> select the Aesir service.
3. Chat as usual. Turn 2+ of a chat reuses the cached prefix (system + history head);
   responses carry usage.reused_prompt_tokens if you want to watch it work.

## Switch back to Ollama
1. Configuration sets -> Default -> Text Generation role -> select the Ollama service
   (http://127.0.0.1:11434). Nothing else changes.

## Start / stop the Aesir serve
- Stop:  sudo systemctl stop aesir-gate.service
- Start: sudo systemd-run --unit=aesir-gate -p User=volmarr -p MemoryHigh=24G -p MemoryMax=32G -p WorkingDirectory=/home/volmarr/aesir-hipserve /bin/bash -c 'export LD_LIBRARY_PATH=.pixi/envs/default/lib:.aesir/shims; exec ./.aesir/aesir serve llama3-3b:latest --accel hip --api-key-file /home/volmarr/.config/aesir/service.key --context 16384 --max-tokens 512 --port 18434 > hidden_files/hip-serve/serve-bench.log 2>&1'
- Note: while the serve is alive it holds its graphics-pool arena (that is the HIP
  runtime's allocation style); stopping the unit frees it. Voxta and Ollama are
  separate services and are never touched by any of this.
