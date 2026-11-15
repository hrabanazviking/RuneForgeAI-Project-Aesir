#!/usr/bin/env bash
exec >> /home/volmarr/aesir-qs-hip/hidden_files/qwen35-speed/qs2-session-fuse5.log 2>&1
cd /home/volmarr/aesir-qs-hip
export LD_LIBRARY_PATH="$PWD/hidden_files/hip-serve/shims"
./hidden_files/qwen35-speed/test_qwen35_hip_session_q35_6 aesir_engine/tests/fixtures/qwen35_forward.gguf
echo SESSION_EXIT=$?
