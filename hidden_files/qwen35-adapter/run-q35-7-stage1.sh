#!/usr/bin/env bash
set -x
cd /home/volmarr/aesir-q35-7
export PATH="$HOME/.pixi/bin:$PATH"
SH=hidden_files/hip-serve/shims
export LD_LIBRARY_PATH="$PWD/$SH"
FX=aesir_engine/tests/fixtures
REAL=/mnt/vault/models/gguf/Qwen3.8-27B-Ultimate-Heretic-Uncn-Turbo-Brilli-50x-AGI-NEO-Q8_0.gguf
A=hidden_files/qwen35-adapter
grep MemAvailable /proc/meminfo
$A/test_qwen35_loader_q35_1 $FX/qwen35_tiny.gguf $FX/qwen35_tiny_bad_qkv.gguf $FX/qwen35_tiny_type_probe.gguf > $A/q35-7-regress-q35-1.log 2>&1; echo Q351_RUN=$?
$A/test_qwen35_registry_q35_2 $REAL > $A/q35-7-regress-q35-2.log 2>&1; echo Q352_RUN=$?
$A/test_qwen35_forward_q35_3 $FX/qwen35_forward.gguf > $A/q35-7-regress-q35-3.log 2>&1; echo Q353_RUN=$?
$A/test_qwen35_resident_q35_3r $FX/qwen35_forward.gguf $FX/qwen35_forward_f16probe.gguf > $A/q35-7-regress-q35-3r.log 2>&1; echo Q353R_RUN=$?
$A/test_qwen35_session_q35_4 $FX/qwen35_forward.gguf > $A/q35-7-regress-q35-4.log 2>&1; echo Q354_RUN=$?
$A/test_qwen35_snapshot_q35_5 $FX/qwen35_forward.gguf > $A/q35-7-regress-q35-5.log 2>&1; echo Q355_RUN=$?
$A/probe_qwen35_runtime_ripple_q35_2 $REAL $FX/qwen35_forward.gguf > $A/q35-7-ripple.log 2>&1; echo RIPPLE_RUN=$?
grep MemAvailable /proc/meminfo
/usr/bin/time -v $A/ref_qwen35_realfile_q35_4b $REAL turns > $A/q35-7-ref-turns.log 2>&1; echo REF_TURNS_RUN=$?
grep MemAvailable /proc/meminfo
/usr/bin/time -v $A/ref_qwen35_realfile_q35_4b $REAL long $A/q35-4b-long-prompt.txt > $A/q35-7-ref-long.log 2>&1; echo REF_LONG_RUN=$?
grep MemAvailable /proc/meminfo
echo STAGE1_RUNS_DONE
