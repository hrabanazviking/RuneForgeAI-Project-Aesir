# tests/run_all.mojo
# The Grand Proving: Master Test Runner for Project Aesir
#
# Invokes every verification rite in sequence.
# Run with: pixi run mojo run tests/run_all.mojo

from tests.test_compute import test_gemm, test_flash_attention, test_silu, test_geglu, test_dequantize_q4_k_m
from tests.test_gguf import test_gguf_parsing, test_ggml_type
from tests.test_tokenizer import test_tokenizer

def main():
    print("==============================================")
    print("  ⚡ Project Aesir — The Grand Proving ⚡")
    print("==============================================")
    print("")
    
    # --- Compute Kernels ---
    print("  [DOMAIN] Core Compute Kernels")
    print("  -----------------------------------------")
    test_gemm()
    test_flash_attention()
    test_silu()
    test_geglu()
    test_dequantize_q4_k_m()
    print("")
    
    # --- GGUF Loader ---
    print("  [DOMAIN] GGUFSeer Loader")
    print("  -----------------------------------------")
    test_gguf_parsing()
    test_ggml_type()
    print("")
    
    # --- Tokenizer ---
    print("  [DOMAIN] RuneWeaver Tokenizer")
    print("  -----------------------------------------")
    test_tokenizer()
    print("")
    
    print("==============================================")
    print("  All rites concluded. The engine stands.")
    print("==============================================")
