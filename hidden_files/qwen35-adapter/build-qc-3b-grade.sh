#!/usr/bin/env bash
cd /home/volmarr/aesir-qc-3b/hidden_files/qwen35-adapter
LC=/home/volmarr/llama.cpp-build
g++ -O2 -std=c++17 -I$LC/include -I$LC/ggml/include qc3bstream.cpp -o qc3bstream -L$LC/build/bin -lllama -lggml -lggml-base -lggml-cpu -Wl,-rpath,$LC/build/bin -lpthread > qc-3b-grade-build.log 2>&1; echo STREAM_BUILD_EXIT=$?
g++ -O2 -std=c++17 -I$LC/include -I$LC/ggml/include qc3bgrade.cpp -o qc3bgrade -L$LC/build/bin -lllama -lggml -lggml-base -lggml-cpu -Wl,-rpath,$LC/build/bin -lpthread >> qc-3b-grade-build.log 2>&1; echo GRADE_BUILD_EXIT=$?
tail -n 5 qc-3b-grade-build.log
ls -la qc3bstream qc3bgrade
