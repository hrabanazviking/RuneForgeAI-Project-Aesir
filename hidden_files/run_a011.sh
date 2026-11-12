#!/bin/bash
# A-011 E-MASTER gate run for team-02 (canonical shape per run_a003.sh,
# extended with the A-011 HIP shim staging: libaesir_hip.so).
cd /home/volmarr/aesir-team-02 || exit 99
export PATH=$HOME/.pixi/bin:$PATH
{
echo "=== A-011 E-MASTER run (team-02, A-011 HIP memory) ==="
date -Is; hostname; uname -a
grep -m1 'model name' /proc/cpuinfo; nproc; free -g | head -n 2
git rev-parse HEAD; git branch --show-current
mojo --version 2>&1 || .pixi/envs/default/bin/mojo --version
ls -l /usr/lib/x86_64-linux-gnu/libamdhip64.so.7
} > hidden_files/a011_run_all_canonical.log 2>&1
staging=$(mktemp -d)
echo "staging=$staging" >> hidden_files/a011_run_all_canonical.log
cc -std=c11 -fPIC -shared aesir_engine/hailo10h_stub.c -o "$staging/libaesir_hailo10h.so" >> hidden_files/a011_run_all_canonical.log 2>&1
echo "stub_cc_exit=$?" >> hidden_files/a011_run_all_canonical.log
cc -std=c11 -O2 -fPIC -shared aesir_engine/thread_par.c -o "$staging/libaesir_par.so" -lpthread >> hidden_files/a011_run_all_canonical.log 2>&1
echo "par_cc_exit=$?" >> hidden_files/a011_run_all_canonical.log
cc -std=c11 -O2 -fPIC -shared aesir_engine/hip_memory_shim.c -o "$staging/libaesir_hip.so" -ldl >> hidden_files/a011_run_all_canonical.log 2>&1
echo "hip_cc_exit=$?" >> hidden_files/a011_run_all_canonical.log
echo "=== mojo run (CPU, canonical sm_89 compile-target, CPU execution; HIP cases execute on the AMD GPU via HIP) start $(date -Is) ===" >> hidden_files/a011_run_all_canonical.log
/usr/bin/time -v pixi run --frozen mojo run -I . --target-accelerator sm_89 -Xlinker "-L$staging" -Xlinker -laesir_hailo10h -Xlinker -laesir_par -Xlinker -laesir_hip aesir_engine/tests/run_all.mojo >> hidden_files/a011_run_all_canonical.log 2>&1
echo "MOJO_EXIT=$?" >> hidden_files/a011_run_all_canonical.log
echo "=== end $(date -Is) ===" >> hidden_files/a011_run_all_canonical.log
