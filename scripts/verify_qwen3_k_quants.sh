#!/usr/bin/env bash
set -euo pipefail

# Pinned fixtures: unsloth/Qwen3-0.6B-GGUF revision
# 50968a4468ef4233ed78cd7c3de230dd1d61a56b
# Q4_K_M 396705472 ac2d97712095a558e31573f62f466a3f9d93990898b0ec79d7c974c1780d524a
# Q5_K_M 444415680 03c6e2127d155b89c21a512954010486b1e00e1a9eebdfad650d03b53ab4c74a
# Q6_K   495107776 1c15a88244c9e852516e5ba0e394fc97f2182f1f2757413fb99fe6a9214c033b

if [[ $# -ne 4 ]]; then
    echo "usage: verify_qwen3_k_quants.sh <aesir-binary> <Q4_K_M.gguf> <Q5_K_M.gguf> <Q6_K.gguf>" >&2
    exit 2
fi

binary=$1
shift
models=("$@")
quantizations=("Q4_K_M" "Q5_K_M" "Q6_K")
sizes=(396705472 444415680 495107776)
hashes=(
    ac2d97712095a558e31573f62f466a3f9d93990898b0ec79d7c974c1780d524a
    03c6e2127d155b89c21a512954010486b1e00e1a9eebdfad650d03b53ab4c74a
    1c15a88244c9e852516e5ba0e394fc97f2182f1f2757413fb99fe6a9214c033b
)

for i in "${!models[@]}"; do
    model=${models[$i]}
    quantization=${quantizations[$i]}
    [[ $(stat -c %s "$model") == "${sizes[$i]}" ]]
    digest=$(sha256sum "$model")
    [[ ${digest%% *} == "${hashes[$i]}" ]]
    inspection=$("$binary" inspect "$model" --format json)
    grep -Fq "\"quantization\":\"$quantization\"" <<<"$inspection"
    grep -Fq '"compatibility":"VERIFIED"' <<<"$inspection"
    grep -Fq '"status":"READY"' <<<"$inspection"

    generation=$("$binary" run "$model" --accel cuda --max-tokens 1 "Reply with OK.")
    grep -Fq '[CUDA] native Mojo Qwen 3 0.6B' <<<"$generation"
    grep -Fq 'generated_tokens=1' <<<"$generation"
    echo "$quantization: VERIFIED"
done

echo "PASS: Qwen Q4_K_M, Q5_K_M, and Q6_K inspect, load, and generate on CUDA"
