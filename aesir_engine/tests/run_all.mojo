# tests/run_all.mojo
# The Grand Proving: Master Test Runner for Project Aesir
#
# Invokes every verification rite in sequence.
# Run with: pixi run mojo run tests/run_all.mojo

from tests.test_compute import (
    test_gemm,
    test_flash_attention,
    test_silu,
    test_geglu,
    test_dequantize_q4_k_m,
)
from tests.test_gguf import test_gguf_parsing, test_ggml_type
from tests.test_tokenizer import test_tokenizer
from tests.test_inference import (
    test_forward_pass,
    test_generation_stop_policy,
    test_unsupported_runtime_config,
)
from tests.test_kv_cache import test_kv_cache
from tests.test_rag import (
    test_cosine_similarity,
    test_mimir_store,
    report_engine_integration_boundary,
)
from tests.test_sharding import (
    test_device_topology,
    test_shard_tensor,
    test_tensor_partitioning,
    test_all_reduce_sum,
    test_sharded_gemm_parity,
)
from tests.test_npu_edge import (
    test_npu_backend_enum,
    test_device_topology_npu,
    test_npu_buffer_zero_copy,
    test_arm_neon_precision,
    test_npu_gemm_parity,
)
from tests.test_gpu_realms import (
    test_gpu_realm_enum,
    test_device_topology_gpus,
    test_gpu_buffer_zero_copy,
    test_gpu_gemm_parity,
)
from tests.test_cuda_realm import (
    test_cuda_gate_availability,
    test_cuda_gemm_dispatch_bounds,
    test_cuda_realm_unsupported_gateways,
)
from tests.test_cli import (
    test_modelfile_parser,
    test_model_manifest_store,
    test_cli_command_dispatch,
    test_repl_session_and_slash_commands,
    test_cli_flag_options_parser,
)
from tests.test_quantization import (
    test_compressed_format_enum,
    test_dequantization_kernels,
)
from tests.test_multi_engine import (
    test_openai_api_formatter,
    test_gbnf_grammar,
    test_speculative_engine,
    test_onnx_model_seer,
    test_multi_engine_cli,
    test_unsupported_http_responses,
    test_posix_socket_server,
    test_http_parser_and_router,
    test_http_response_framing,
    test_openai_rest_gateway,
)
from tests.test_resilience import (
    test_error_guard,
    test_state_vault,
    test_event_bus,
    test_thread_pool,
    test_supervisor_crash_recovery,
)
from tests.test_huggingface import (
    test_hf_repo_parsing,
    test_hf_download_url_builder,
    test_hf_mobile_model_download,
)
from tests.test_swarm_cluster import (
    test_swarm_node_role,
    test_peer_node_metrics,
    test_peer_registry_and_load_balancer,
    test_swarm_cluster_task_dispatch,
)
from tests.test_ledger import TestLedger, run_case, record_skip


def main() raises:
    var ledger = TestLedger()

    print("==============================================")
    print("  ⚡ Project Aesir — The Grand Proving ⚡")
    print("==============================================")
    print("")

    # --- Compute Kernels ---
    print("  [DOMAIN] Core Compute Kernels")
    print("  -----------------------------------------")
    run_case(ledger, "compute.gemm_f16", test_gemm)
    run_case(ledger, "compute.flash_attention_2", test_flash_attention)
    run_case(ledger, "compute.silu", test_silu)
    run_case(ledger, "compute.geglu", test_geglu)
    run_case(
        ledger, "compute.dequantize_q4_k_m_scaffold", test_dequantize_q4_k_m
    )
    print("")

    # --- GGUF Loader ---
    print("  [DOMAIN] GGUFSeer Loader")
    print("  -----------------------------------------")
    run_case(ledger, "gguf.malformed_model_rejection", test_gguf_parsing)
    run_case(ledger, "gguf.type_constants", test_ggml_type)
    print("")

    # --- Tokenizer ---
    print("  [DOMAIN] RuneWeaver Tokenizer")
    print("  -----------------------------------------")
    run_case(ledger, "tokenizer.synthetic_bpe", test_tokenizer)
    print("")

    # --- Inference Engine ---
    print("  [DOMAIN] The Loom of Fate (Inference)")
    print("  -----------------------------------------")
    run_case(ledger, "inference.synthetic_forward", test_forward_pass)
    run_case(ledger, "inference.stop_policy", test_generation_stop_policy)
    run_case(
        ledger,
        "inference.unsupported_runtime_config",
        test_unsupported_runtime_config,
    )
    run_case(ledger, "inference.kv_cache", test_kv_cache)
    print("")

    # --- Logical Host Tensor Partitioning ---
    print("  [DOMAIN] Logical Host Tensor Partitioning")
    print("  -----------------------------------------")
    run_case(ledger, "sharding.logical_host_topology", test_device_topology)
    run_case(ledger, "sharding.tensor_descriptor", test_shard_tensor)
    run_case(ledger, "sharding.row_column_partition", test_tensor_partitioning)
    run_case(ledger, "sharding.host_all_reduce", test_all_reduce_sum)
    run_case(ledger, "sharding.host_gemm_parity", test_sharded_gemm_parity)
    print("")

    # --- Local Vector and RAG Building Blocks ---
    print("  [DOMAIN] Local Vector and RAG Building Blocks")
    print("  -----------------------------------------")
    run_case(ledger, "rag.cosine_similarity", test_cosine_similarity)
    run_case(ledger, "rag.in_memory_store", test_mimir_store)
    report_engine_integration_boundary()
    record_skip(
        ledger,
        "rag.real_engine_integration",
        "requires a validated external GGUF fixture",
    )
    print("")

    # --- NPU Descriptors and Unsupported Gateway ---
    print("  [DOMAIN] NPU Descriptors and Unsupported Execution Gateway")
    print("  -----------------------------------------")
    run_case(ledger, "npu.enum", test_npu_backend_enum)
    run_case(ledger, "npu.no_fabricated_detection", test_device_topology_npu)
    run_case(ledger, "npu.host_buffer_view", test_npu_buffer_zero_copy)
    run_case(ledger, "npu.host_simd8_parity", test_arm_neon_precision)
    run_case(ledger, "npu.unsupported_execution", test_npu_gemm_parity)
    print("")

    # --- GPU Descriptors and CUDA Execution Gateway ---
    print("  [DOMAIN] GPU Descriptors and CUDA Execution Gateway")
    print("  -----------------------------------------")
    run_case(ledger, "gpu.enum", test_gpu_realm_enum)
    run_case(ledger, "gpu.no_fabricated_detection", test_device_topology_gpus)
    run_case(ledger, "gpu.host_buffer_view", test_gpu_buffer_zero_copy)
    run_case(ledger, "gpu.unsupported_execution", test_gpu_gemm_parity)
    run_case(ledger, "gpu.cuda_gate_availability", test_cuda_gate_availability)
    run_case(ledger, "gpu.cuda_gemm_dispatch_bounds", test_cuda_gemm_dispatch_bounds)
    run_case(ledger, "gpu.cuda_realm_unsupported_gateways", test_cuda_realm_unsupported_gateways)
    print("")

    # --- Implemented CLI and Unsupported Boundaries ---
    print("  [DOMAIN] Implemented CLI and Unsupported Boundaries")
    print("  -----------------------------------------")
    run_case(ledger, "cli.modelfile_parser", test_modelfile_parser)
    run_case(ledger, "cli.in_memory_manifest_store", test_model_manifest_store)
    run_case(ledger, "cli.truthful_command_boundaries", test_cli_command_dispatch)
    run_case(ledger, "cli.repl_session_state", test_repl_session_and_slash_commands)
    run_case(ledger, "cli.flag_options_parser", test_cli_flag_options_parser)
    print("")

    # --- Compressed Format Scaffolds ---
    print("  [DOMAIN] Compressed Format Scaffolds")
    print("  -----------------------------------------")
    run_case(ledger, "quantization.enum", test_compressed_format_enum)
    run_case(
        ledger, "quantization.dispatch_writes", test_dequantization_kernels
    )
    print("")

    # --- Formatter and Unsupported Ecosystem Boundaries ---
    print("  [DOMAIN] Formatter and Unsupported Ecosystem Boundaries")
    print("  -----------------------------------------")
    run_case(ledger, "multi_engine.openai_formatter", test_openai_api_formatter)
    run_case(ledger, "multi_engine.grammar_mask", test_gbnf_grammar)
    run_case(
        ledger, "multi_engine.speculative_acceptance", test_speculative_engine
    )
    run_case(ledger, "multi_engine.onnx_unavailable", test_onnx_model_seer)
    run_case(ledger, "multi_engine.cli_unsupported", test_multi_engine_cli)
    run_case(
        ledger,
        "multi_engine.http_unsupported_responses",
        test_unsupported_http_responses,
    )
    run_case(ledger, "server.posix_socket", test_posix_socket_server)
    run_case(ledger, "server.http_parser", test_http_parser_and_router)
    run_case(
        ledger, "server.http_response_framing", test_http_response_framing
    )
    run_case(
        ledger, "server.openai_rest_gateway", test_openai_rest_gateway
    )
    print("")

    # --- Local Resilience Scaffolds ---
    print("  [DOMAIN] Local Resilience Scaffolds")
    print("  -----------------------------------------")
    run_case(ledger, "resilience.error_guard", test_error_guard)
    run_case(ledger, "resilience.state_vault_marker", test_state_vault)
    run_case(ledger, "resilience.event_bus_marker", test_event_bus)
    run_case(ledger, "resilience.thread_pool_stub", test_thread_pool)
    run_case(
        ledger,
        "resilience.supervisor_simulation_marker",
        test_supervisor_crash_recovery,
    )
    print("")

    # --- Hugging Face String Helpers and Unsupported Download ---
    print("  [DOMAIN] Hugging Face String Helpers and Unsupported Download")
    print("  -----------------------------------------")
    run_case(ledger, "huggingface.tag_parser", test_hf_repo_parsing)
    run_case(ledger, "huggingface.url_builder", test_hf_download_url_builder)
    run_case(
        ledger, "huggingface.download_unsupported", test_hf_mobile_model_download
    )
    print("")

    # --- Local Swarm Descriptors and Unsupported Networking ---
    print("  [DOMAIN] Local Swarm Descriptors and Unsupported Networking")
    print("  -----------------------------------------")
    run_case(ledger, "swarm.role_enum", test_swarm_node_role)
    run_case(ledger, "swarm.peer_metrics", test_peer_node_metrics)
    run_case(
        ledger,
        "swarm.registry_load_balancer",
        test_peer_registry_and_load_balancer,
    )
    run_case(
        ledger, "swarm.network_unsupported", test_swarm_cluster_task_dispatch
    )
    print("")

    ledger.finish(61)
