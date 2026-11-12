#!/bin/bash
cd /home/volmarr/aesir-team-01 || exit 99
export PATH=$HOME/.pixi/bin:$PATH
{
echo "=== A-010 E-MASTER run (HIP device gate) ==="
date -Is; hostname; uname -a
grep -m1 'model name' /proc/cpuinfo; nproc; free -g | head -n 2
git rev-parse HEAD; git branch --show-current
mojo --version 2>&1 || .pixi/envs/default/bin/mojo --version
} > hidden_files/a010_run_all.log 2>&1
staging=$(mktemp -d)
echo "staging=$staging" >> hidden_files/a010_run_all.log
cc -std=c11 -fPIC -shared aesir_engine/hailo10h_stub.c -o "$staging/libaesir_hailo10h.so" >> hidden_files/a010_run_all.log 2>&1
echo "stub_cc_exit=$?" >> hidden_files/a010_run_all.log
cc -std=c11 -O2 -fPIC -shared aesir_engine/thread_par.c -o "$staging/libaesir_par.so" -lpthread >> hidden_files/a010_run_all.log 2>&1
echo "par_cc_exit=$?" >> hidden_files/a010_run_all.log
cc -std=c11 -O2 -fPIC -shared aesir_engine/hip_bridge.c -o "$staging/libaesir_hip.so" -ldl >> hidden_files/a010_run_all.log 2>&1
echo "hip_cc_exit=$?" >> hidden_files/a010_run_all.log
echo "=== mojo run (CPU, canonical sm_89 compile-target, CPU execution) start $(date -Is) ===" >> hidden_files/a010_run_all.log
/usr/bin/time -v pixi run --frozen mojo run -I . --target-accelerator sm_89 -Xlinker "-L$staging" -Xlinker -laesir_hailo10h -Xlinker -laesir_par -Xlinker -laesir_hip aesir_engine/tests/run_all.mojo >> hidden_files/a010_run_all.log 2>&1
echo "MOJO_EXIT=$?" >> hidden_files/a010_run_all.log
echo "=== end $(date -Is) ===" >> hidden_files/a010_run_all.log
