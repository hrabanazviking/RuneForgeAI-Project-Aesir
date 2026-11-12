#!/bin/bash
cd /home/volmarr/aesir-team-09 || exit 99
export PATH=$HOME/.pixi/bin:$PATH
{
echo "=== A-009 E-MASTER run (team-09, backend registry) ==="
date -Is; hostname; git rev-parse HEAD; git branch --show-current
mojo --version 2>&1 || .pixi/envs/default/bin/mojo --version
} > hidden_files/a009_run_all.log 2>&1
staging=$(mktemp -d)
cc -std=c11 -fPIC -shared aesir_engine/hailo10h_stub.c -o "$staging/libaesir_hailo10h.so" >> hidden_files/a009_run_all.log 2>&1; echo "stub_cc_exit=$?" >> hidden_files/a009_run_all.log
cc -std=c11 -O2 -fPIC -shared aesir_engine/thread_par.c -o "$staging/libaesir_par.so" -lpthread >> hidden_files/a009_run_all.log 2>&1; echo "par_cc_exit=$?" >> hidden_files/a009_run_all.log
/usr/bin/time -v pixi run --frozen mojo run -I . --target-accelerator sm_89 -Xlinker "-L$staging" -Xlinker -laesir_hailo10h -Xlinker -laesir_par aesir_engine/tests/run_all.mojo >> hidden_files/a009_run_all.log 2>&1
echo "MOJO_EXIT=$?" >> hidden_files/a009_run_all.log
