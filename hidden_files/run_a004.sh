#!/bin/bash
cd /home/volmarr/aesir-team-04 || exit 99
export PATH=$HOME/.pixi/bin:$PATH
FIX=/home/volmarr/aesir-team-04/hidden_files/fixtures/stories260K.F16.gguf
{
echo "=== A-004 E-REAL on Z13 CPU ==="
date -Is; hostname; uname -a
grep -m1 'model name' /proc/cpuinfo; nproc; free -g | head -n 2
git rev-parse HEAD; git branch --show-current
sha256sum "$FIX"
.pixi/envs/default/bin/mojo --version
} > hidden_files/a004_ereal.log 2>&1
staging=$(mktemp -d)
echo "staging=$staging" >> hidden_files/a004_ereal.log
cc -std=c11 -fPIC -shared aesir_engine/hailo10h_stub.c -o "$staging/libaesir_hailo10h.so" >> hidden_files/a004_ereal.log 2>&1
echo "stub_cc_exit=$?" >> hidden_files/a004_ereal.log
cc -std=c11 -O2 -fPIC -shared aesir_engine/thread_par.c -o "$staging/libaesir_par.so" -lpthread >> hidden_files/a004_ereal.log 2>&1
echo "par_cc_exit=$?" >> hidden_files/a004_ereal.log
echo "=== mojo run E-REAL start $(date -Is) ===" >> hidden_files/a004_ereal.log
/usr/bin/time -v pixi run --frozen mojo run -I . --target-accelerator sm_89 -Xlinker "-L$staging" -Xlinker -laesir_hailo10h -Xlinker -laesir_par aesir_engine/tests/test_real_gguf.mojo "$FIX" >> hidden_files/a004_ereal.log 2>&1
echo "MOJO_EXIT=$?" >> hidden_files/a004_ereal.log
echo "=== end $(date -Is) ===" >> hidden_files/a004_ereal.log
