#!/usr/bin/env bash
cd /home/volmarr/aesir-qc-3b
H=hidden_files/qwen35-adapter
export PATH="$HOME/.pixi/bin:$PATH"
export LD_LIBRARY_PATH="$PWD/hidden_files/hip-serve/shims:$LD_LIBRARY_PATH"
SH=hidden_files/hip-serve/shims
LK="-Xlinker -L$SH -Xlinker -laesir_hailo10h -Xlinker -laesir_par -Xlinker -laesir_hip -Xlinker -laesir_vulkan -Xlinker -laesir_zc -Xlinker -laesir_aff"
pixi run --frozen mojo build -I . --target-accelerator gfx1151 $LK aesir_engine/tests/test_dequantize_input_qc_3b.mojo -o $H/test_dequantize_input_qc_3b > $H/qc-3b-dequant-build.log 2>&1; echo DEQUANT_BUILD_EXIT=$?
$H/test_dequantize_input_qc_3b > $H/qc-3b-dequant-test.log 2>&1; echo DEQUANT_TEST_EXIT=$?
GEMMA=/home/volmarr/aesir-forge/.aesir/models/gemma-4-E2B-it-Q4_K_M.gguf
grep MemAvailable /proc/meminfo > $H/qc-3b-rss-mem.log
/usr/bin/time -v $H/test_gguf_writer_streaming_qc_3b gemma-mem $GEMMA /tmp/qc3b-gemma-mem.gguf > $H/qc-3b-gemma-mem.log 2> $H/qc-3b-gemma-mem-time.log; echo GEMMA_MEM_EXIT=$?
grep MemAvailable /proc/meminfo >> $H/qc-3b-rss-mem.log
/usr/bin/time -v $H/test_gguf_writer_streaming_qc_3b gemma-stream $GEMMA /tmp/qc3b-gemma-stream.gguf > $H/qc-3b-gemma-stream.log 2> $H/qc-3b-gemma-stream-time.log; echo GEMMA_STREAM_EXIT=$?
cmp $GEMMA /tmp/qc3b-gemma-mem.gguf && echo MEM_COPY_IDENTICAL; cmp $GEMMA /tmp/qc3b-gemma-stream.gguf && echo STREAM_COPY_IDENTICAL
sha256sum $GEMMA /tmp/qc3b-gemma-mem.gguf /tmp/qc3b-gemma-stream.gguf > $H/qc-3b-gemma-copy-sha.log 2>&1; cat $H/qc-3b-gemma-copy-sha.log
rm -f /tmp/qc3b-gemma-mem.gguf /tmp/qc3b-gemma-stream.gguf
echo QC3B_STAGE1C_DONE
