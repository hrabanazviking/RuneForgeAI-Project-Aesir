#!/bin/bash
# znver2 acceptance: build GPU-branch test_llama3_spill with --mcpu znver2.
# usage: znver2_build.sh <tree_dir> <compute.mojo> <out_name> <log>
set -u
tree="$1"; comp="$2"; out="$3"; log="$4"
cp "$comp" "$tree/aesir_engine/core/compute.mojo"
stage="$tree/.stage"
mkdir -p "$stage"
cc -std=c11 -fPIC -shared "$tree/aesir_engine/hailo10h_stub.c" -o "$stage/libaesir_hailo10h.so"
cc -std=c11 -O2 -fPIC -shared "$tree/aesir_engine/thread_par.c" -o "$stage/libaesir_par.so" -lpthread
cd "$tree"
MOJO=~/workspace/aesir-llvm-fix/.pixi/envs/default/bin/mojo
"$MOJO" --version >> "$log" 2>&1
time "$MOJO" build --mcpu znver2 -I . -I aesir_engine --target-accelerator sm_89 aesir_engine/tests/test_llama3_spill.mojo -o "$out" -Xlinker "-L$stage" -Xlinker -laesir_hailo10h -Xlinker -laesir_par -Xlinker -rpath -Xlinker '$ORIGIN' >> "$log" 2>&1
echo "ZNVER2_EXIT=$?" >> "$log"
