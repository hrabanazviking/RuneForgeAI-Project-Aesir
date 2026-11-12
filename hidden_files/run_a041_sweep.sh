#!/bin/bash
# A-041 thread-scaling sweep. Usage: run_a041_sweep.sh <label>
# Builds the bench against the CURRENT worktree engine code, then
# runs it once per AESIR_THREADS rung x 3 trials (plus one default
# -env run). Decode engagement: AESIR_PAR_MIN_WORK=1 (see bench
# header). All output lands in hidden_files/a041_sweep_<label>.log
set -u
LABEL=$1
cd /home/volmarr/aesir-team-09 || exit 99
export PATH=$HOME/.pixi/bin:$PATH
LOG=hidden_files/a041_sweep_${LABEL}.log
{
date -Is; hostname; uname -a; git rev-parse HEAD; git branch --show-current
uptime; nproc
sha256sum hidden_files/fixtures/stories260K.F16.gguf aesir_engine/tests/bench_thread_scaling_a041.mojo aesir_engine/core/parallel.mojo aesir_engine/thread_par.c
} > $LOG 2>&1
staging=$(mktemp -d); echo staging=$staging >> $LOG
cc -std=c11 -fPIC -shared aesir_engine/hailo10h_stub.c -o "$staging/libaesir_hailo10h.so" >> $LOG 2>&1
cc -std=c11 -O2 -fPIC -shared aesir_engine/thread_par.c -o "$staging/libaesir_par.so" -lpthread >> $LOG 2>&1
cc -std=c11 -O2 -fPIC -shared aesir_engine/hip_memory_shim.c -o "$staging/libaesir_hip.so" -ldl >> $LOG 2>&1
cc -std=c11 -O2 -fPIC -shared aesir_engine/vulkan_context_shim.c aesir_engine/vulkan_buffer_shim.c -o "$staging/libaesir_vulkan.so" -ldl >> $LOG 2>&1
cc -std=c11 -O2 -fPIC -shared aesir_engine/zero_copy_shim.c -o "$staging/libaesir_zc.so" -ldl >> $LOG 2>&1
cc -std=c11 -O2 -fPIC -shared aesir_engine/affinity_shim.c -o "$staging/libaesir_aff.so" >> $LOG 2>&1
echo shims_done >> $LOG
pixi run --frozen mojo build -I . --target-accelerator gfx1151 -Xlinker "-L$staging" -Xlinker -laesir_hailo10h -Xlinker -laesir_par -Xlinker -laesir_hip -Xlinker -laesir_vulkan -Xlinker -laesir_zc -Xlinker -laesir_aff -o /tmp/a041_bench_${LABEL} aesir_engine/tests/bench_thread_scaling_a041.mojo >> $LOG 2>&1
echo BUILD_EXIT=$? >> $LOG
for T in default 1 2 4 6 8 12 16 20 24 28 32; do
  for trial in 1 2 3; do
    echo "=== RUNG threads=$T trial=$trial ===" >> $LOG
    if [ "$T" = "default" ]; then
      env -u AESIR_THREADS AESIR_PAR_MIN_WORK=1 LD_LIBRARY_PATH=$staging /tmp/a041_bench_${LABEL} hidden_files/fixtures/stories260K.F16.gguf 25 >> $LOG 2>&1
    else
      AESIR_THREADS=$T AESIR_PAR_MIN_WORK=1 LD_LIBRARY_PATH=$staging /tmp/a041_bench_${LABEL} hidden_files/fixtures/stories260K.F16.gguf 25 >> $LOG 2>&1
    fi
    echo "RUN_EXIT=$?" >> $LOG
  done
done
for T in default 32; do
  for trial in 1 2; do
    echo "=== PROD RUNG threads=$T trial=$trial (AESIR_PAR_MIN_WORK unset) ===" >> $LOG
    if [ "$T" = "default" ]; then
      env -u AESIR_THREADS -u AESIR_PAR_MIN_WORK LD_LIBRARY_PATH=$staging /tmp/a041_bench_${LABEL} hidden_files/fixtures/stories260K.F16.gguf 200 >> $LOG 2>&1
    else
      env -u AESIR_PAR_MIN_WORK AESIR_THREADS=$T LD_LIBRARY_PATH=$staging /tmp/a041_bench_${LABEL} hidden_files/fixtures/stories260K.F16.gguf 200 >> $LOG 2>&1
    fi
    echo "RUN_EXIT=$?" >> $LOG
  done
done
uptime >> $LOG
echo A041_SWEEP_${LABEL}_DONE >> $LOG
