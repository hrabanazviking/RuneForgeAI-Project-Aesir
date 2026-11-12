#!/bin/bash
cd /home/volmarr/aesir-team-09 || exit 99
export PATH=$HOME/.pixi/bin:$PATH
staging=$(mktemp -d)
cc -std=c11 -fPIC -shared aesir_engine/hailo10h_stub.c -o "$staging/libaesir_hailo10h.so"
cc -std=c11 -O2 -fPIC -shared aesir_engine/thread_par.c -o "$staging/libaesir_par.so" -lpthread
pixi run --frozen mojo run -I . -I aesir_engine --target-accelerator sm_89 -Xlinker "-L$staging" -Xlinker -laesir_hailo10h -Xlinker -laesir_par aesir_engine/main.mojo doctor "$@"
