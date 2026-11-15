#!/usr/bin/env bash
exec >> /home/volmarr/aesir-qs-hip/hidden_files/qwen35-speed/qs2-fixture-driver.log 2>&1
export TAG=v8
/usr/bin/bash /home/volmarr/aesir-qs-hip/hidden_files/qwen35-speed/run-qs2-fixture.sh
