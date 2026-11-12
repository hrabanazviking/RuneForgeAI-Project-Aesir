#!/bin/bash
cd /home/volmarr/aesir-team-02 || exit 99
export PATH=$HOME/.pixi/bin:$PATH
staging=$(mktemp -d)
cc -std=c11 -O2 -fPIC -shared aesir_engine/vulkan_context_shim.c aesir_engine/vulkan_buffer_shim.c -o "$staging/libaesir_vulkan.so" -ldl || exit 98
cat > /tmp/a066_driver.mojo <<'DRV'
from tests.test_vulkan_decode_a066 import (
    test_vulkan_decode_kv_append_parity,
    test_vulkan_decode_strided_attention_parity,
    test_vulkan_decode_token_exact,
    test_vulkan_decode_rejection,
)
def main() raises:
    test_vulkan_decode_kv_append_parity()
    test_vulkan_decode_strided_attention_parity()
    test_vulkan_decode_token_exact()
    test_vulkan_decode_rejection()
    print("A066 DRIVER ALL PASS")
DRV
cp /tmp/a066_driver.mojo aesir_engine/tests/a066_driver.mojo
pixi run --frozen mojo run -I . --target-accelerator gfx1151 -Xlinker "-L$staging" -Xlinker -laesir_vulkan aesir_engine/tests/a066_driver.mojo > hidden_files/a066_driver.log 2>&1
echo "MOJO_EXIT=$?" >> hidden_files/a066_driver.log
rm -f aesir_engine/tests/a066_driver.mojo
cat hidden_files/a066_driver.log
