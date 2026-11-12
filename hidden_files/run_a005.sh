#!/bin/bash
# A-005 E-MASTER gate run for team-05 (canonical shape per run_a003.sh,
# plus A-005 ROCm evidence header: rocminfo + unversioned libamdhip64.so).
cd /home/volmarr/aesir-team-05 || exit 99
export PATH=$HOME/.pixi/bin:$PATH
{
echo "=== A-005 E-MASTER run (team-05, ROCm userland natively) ==="
date -Is; hostname; uname -a
grep -m1 'model name' /proc/cpuinfo; nproc; free -g | head -n 2
git rev-parse HEAD; git branch --show-current
mojo --version 2>&1 || .pixi/envs/default/bin/mojo --version
echo "--- A-005 ROCm evidence ---"
rocminfo 2>&1 | grep -A2 'Agent 2'
ls -l /usr/lib/x86_64-linux-gnu/libamdhip64.so
dpkg-query -W -f='${Package} ${Version}\n' rocminfo libamdhip64-dev libamdhip64-7 libhiprtc7 libhsa-runtime-dev
} > hidden_files/a005_run_all_canonical.log 2>&1
staging=$(mktemp -d)
echo "staging=$staging" >> hidden_files/a005_run_all_canonical.log
cc -std=c11 -fPIC -shared aesir_engine/hailo10h_stub.c -o "$staging/libaesir_hailo10h.so" >> hidden_files/a005_run_all_canonical.log 2>&1
echo "stub_cc_exit=$?" >> hidden_files/a005_run_all_canonical.log
cc -std=c11 -O2 -fPIC -shared aesir_engine/thread_par.c -o "$staging/libaesir_par.so" -lpthread >> hidden_files/a005_run_all_canonical.log 2>&1
echo "par_cc_exit=$?" >> hidden_files/a005_run_all_canonical.log
echo "=== mojo run (CPU, canonical sm_89 compile-target, CPU execution) start $(date -Is) ===" >> hidden_files/a005_run_all_canonical.log
/usr/bin/time -v pixi run --frozen mojo run -I . --target-accelerator sm_89 -Xlinker "-L$staging" -Xlinker -laesir_hailo10h -Xlinker -laesir_par aesir_engine/tests/run_all.mojo >> hidden_files/a005_run_all_canonical.log 2>&1
echo "MOJO_EXIT=$?" >> hidden_files/a005_run_all_canonical.log
echo "=== end $(date -Is) ===" >> hidden_files/a005_run_all_canonical.log
