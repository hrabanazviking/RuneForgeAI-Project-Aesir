#!/usr/bin/env bash
cd /home/volmarr/aesir-qc-3b
H=hidden_files/qwen35-adapter
export LD_LIBRARY_PATH="$PWD/hidden_files/hip-serve/shims:$LD_LIBRARY_PATH"
STORIES=/home/volmarr/aesir-team-01/hidden_files/fixtures/stories260K.F16.gguf
.aesir/aesir quantize --streaming $STORIES $H/qc-3b-stories-q8-stream.gguf > $H/qc-3b-stories-stream-cli.log 2>&1; echo STORIES_STREAM_CLI_EXIT=$?
sha256sum $H/qc-3b-stories-q8-stream.gguf > $H/qc-3b-stories-stream-sha.log 2>&1; cat $H/qc-3b-stories-stream-sha.log
GEMMA=/home/volmarr/aesir-forge/.aesir/models/gemma-4-E2B-it-Q4_K_M.gguf
sha256sum $GEMMA > $H/qc-3b-source-sha.log 2>&1; cat $H/qc-3b-source-sha.log
grep MemAvailable /proc/meminfo > $H/qc-3b-convert-mem.log
date > $H/qc-3b-convert-time.log
/usr/bin/time -v .aesir/aesir quantize --streaming $GEMMA $H/gemma-4-E2B-it-Q8_0.gguf > $H/qc-3b-convert.log 2> $H/qc-3b-convert-timev.log; echo CONVERT_EXIT=$?
date >> $H/qc-3b-convert-time.log
grep MemAvailable /proc/meminfo >> $H/qc-3b-convert-mem.log
sha256sum $H/gemma-4-E2B-it-Q8_0.gguf > $H/qc-3b-emitted-sha.log 2>&1; ls -l $H/gemma-4-E2B-it-Q8_0.gguf >> $H/qc-3b-emitted-sha.log 2>&1; cat $H/qc-3b-emitted-sha.log
echo QC3B_CONVERT_DONE
