#!/bin/bash
cd ~/workspace/aesir-llvm-fix
staging="$(mktemp -d)"
cc -std=c11 -fPIC -shared aesir_engine/hailo10h_stub.c -o "$staging/libaesir_hailo10h.so"
cc -std=c11 -O2 -fPIC -shared aesir_engine/thread_par.c -o "$staging/libaesir_par.so" -lpthread
echo "staging=$staging"
time ~/.pixi/bin/pixi run mojo run -I . --target-accelerator sm_89 -Xlinker "-L$staging" -Xlinker -laesir_hailo10h -Xlinker -laesir_par aesir_engine/tests/run_all.mojo
echo "COUNTED_RUN_EXIT=$?"
