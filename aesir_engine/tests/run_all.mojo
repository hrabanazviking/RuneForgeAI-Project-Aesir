# tests/run_all.mojo
# The Grand Proving: Master Test Runner for Project Aesir
#
# Invokes every verification rite in sequence.
# Run with: pixi run mojo run tests/run_all.mojo

from tests.test_compute import test_gemm, test_flash_attention, test_silu, test_geglu, test_dequantize_q4_k_m
from tests.test_gguf import test_gguf_parsing, test_ggml_type
from tests.test_tokenizer import test_tokenizer
from tests.test_inference import test_forward_pass
from tests.test_kv_cache import test_kv_cache
from tests.test_rag import test_rag
from tests.test_sharding import test_sharding
from tests.test_npu_edge import test_npu_backend_enum, test_device_topology_npu, test_npu_buffer_zero_copy, test_arm_neon_precision, test_npu_gemm_parity
from tests.test_gpu_realms import test_gpu_realm_enum, test_device_topology_gpus, test_gpu_buffer_zero_copy, test_gpu_gemm_parity
from tests.test_cli import test_modelfile_parser, test_model_manifest_store, test_cli_command_dispatch
from tests.test_quantization import test_compressed_format_enum, test_dequantization_kernels
from tests.test_multi_engine import test_openai_api_formatter, test_gbnf_grammar, test_speculative_engine, test_onnx_model_seer, test_multi_engine_cli
from tests.test_resilience import test_error_guard, test_state_vault, test_event_bus, test_thread_pool, test_supervisor_crash_recovery
from tests.test_huggingface import test_hf_repo_parsing, test_hf_download_url_builder, test_hf_mobile_model_download
from tests.test_swarm_cluster import test_swarm_node_role, test_peer_node_metrics, test_peer_registry_and_load_balancer, test_swarm_cluster_task_dispatch

def main() raises:
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
    
    # --- Inference Engine ---
    print("  [DOMAIN] The Loom of Fate (Inference)")
    print("  -----------------------------------------")
    test_forward_pass()
    test_kv_cache()
    print("")
    
    # --- Bifrost Shard Matrix (Multi-Device Sharding) ---
    print("  [DOMAIN] The Bifrost Shard Matrix (Multi-Device Sharding)")
    print("  -----------------------------------------")
    test_sharding()
    print("")

    # --- Mímisbrunnr RAG & Vector Search ---
    print("  [DOMAIN] Mímisbrunnr External Knowledge & SIMD Vector Search")
    print("  -----------------------------------------")
    test_rag()
    print("")

    # --- NPU Realm Gateway (Edge & Mobile Acceleration) ---
    print("  [DOMAIN] The NPU Realm Gateway (Edge & Mobile Acceleration)")
    print("  -----------------------------------------")
    test_npu_backend_enum()
    test_device_topology_npu()
    test_npu_buffer_zero_copy()
    test_arm_neon_precision()
    test_npu_gemm_parity()
    print("")

    # --- Universal Multi-GPU & Hardware Accelerator Realm Matrix ---
    print("  [DOMAIN] Universal Multi-GPU & Accelerator Realm Matrix")
    print("  -----------------------------------------")
    test_gpu_realm_enum()
    test_device_topology_gpus()
    test_gpu_buffer_zero_copy()
    test_gpu_gemm_parity()
    print("")

    # --- Complete Ollama Terminal Command Suite ---
    print("  [DOMAIN] Complete Ollama Terminal Command Suite")
    print("  -----------------------------------------")
    test_modelfile_parser()
    test_model_manifest_store()
    test_cli_command_dispatch()
    print("")

    # --- Universal Compressed LLM Format Matrix ---
    print("  [DOMAIN] Universal Compressed LLM Format Matrix")
    print("  -----------------------------------------")
    test_compressed_format_enum()
    test_dequantization_kernels()
    print("")

    # --- Universal Multi-Engine Ecosystem Matrix ---
    print("  [DOMAIN] Universal Multi-Engine Ecosystem Matrix")
    print("  -----------------------------------------")
    test_openai_api_formatter()
    test_gbnf_grammar()
    test_speculative_engine()
    test_onnx_model_seer()
    test_multi_engine_cli()
    print("")

    # --- Sovereign Resilience & Self-Healing Matrix ---
    print("  [DOMAIN] Sovereign Resilience & Self-Healing Matrix")
    print("  -----------------------------------------")
    test_error_guard()
    test_state_vault()
    test_event_bus()
    test_thread_pool()
    test_supervisor_crash_recovery()
    print("")

    # --- HuggingFace Hub Integration & Mobile Downloader ---
    print("  [DOMAIN] HuggingFace Hub Integration & Mobile Downloader")
    print("  -----------------------------------------")
    test_hf_repo_parsing()
    test_hf_download_url_builder()
    test_hf_mobile_model_download()
    print("")

    # --- Autonomous Swarm Agents & Enterprise Mesh Cluster Matrix ---
    print("  [DOMAIN] Autonomous Swarm Agents & Enterprise Mesh Cluster Matrix")
    print("  -----------------------------------------")
    test_swarm_node_role()
    test_peer_node_metrics()
    test_peer_registry_and_load_balancer()
    test_swarm_cluster_task_dispatch()
    print("")

    print("==============================================")
    print("  All rites concluded. The engine stands.")
    print("==============================================")






