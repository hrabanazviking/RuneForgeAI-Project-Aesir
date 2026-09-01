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
from tests.test_local_protocol import test_local_json, test_local_http, test_local_generation_request, test_local_path_bounds
from tests.test_generation_control import test_generation_deadline, test_generation_control_rejection, test_generation_sigint
from tests.test_cgroup_memory import test_cgroup_paths, test_cgroup_hierarchy, test_cgroup_rejection
from tests.test_upload_admission import test_upload_staging_bounds, test_upload_host_admission
from tests.test_sampling_config import test_sampling_syntax, test_sampling_config_rejection, test_sampling_config_updates
from tests.test_cuda_chat_admission import test_cuda_chat_admission
from tests.test_native_planning import test_host_memory_observations, test_native_memory_counts, test_native_memory_rejection, test_native_device_selection, test_native_planning_cli_rejection
from tests.test_inference import (
    test_forward_pass,
    test_generation_stop_policy,
    test_unsupported_runtime_config,
)
from tests.test_kv_cache import test_kv_cache
from tests.test_mimir_well import (
    test_mimir_well_allocation,
    test_kv_cache_ring_buffer,
)
from tests.test_memory_refinements import (
    test_mimir_well_telemetry,
    test_bpe_tokenizer_linear_perf,
)
from tests.test_rag import (
    test_cosine_similarity,
    test_mimir_store,
    test_query_embedding_extraction,
    test_corpus_ingestion,
    test_end_to_end_rag_grounding,
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
from tests.test_hardware_discovery import (
    test_discovery_status_classification,
    test_physical_device_admission,
    test_topology_discovery_accumulation,
    test_topology_stable_selection,
)
from tests.test_cuda_resource_budget import (
    test_cuda_budget_accounting,
    test_cuda_budget_rejection_is_transactional,
    test_cuda_budget_overflow_and_rollback,
    test_cuda_resource_policy_admission,
)
from tests.test_cuda_gemm_plan import (
    test_cuda_gemm_plan_counts_and_launch,
    test_cuda_gemm_plan_shape_rejection,
    test_cuda_gemm_plan_overflow_and_abi_rejection,
    test_cuda_gemm_batch_budget_transaction,
)
from tests.test_cuda_realm import (
    test_cuda_gate_availability,
    test_cuda_gemm_dispatch_bounds,
    test_cuda_realm_unsupported_gateways,
)
from tests.test_onnx import (
    test_onnx_recognized_operators,
    test_onnx_seer_header_validation,
)
from tests.test_exl2 import (
    test_exl2_cuda_contract_validation,
    test_exl2_model_seer,
)
from tests.test_llama_cpp_cli import (
    test_llama_cpp_subcommands,
    test_llama_cpp_arg_parsing,
)
from tests.test_gbnf_grammar import (
    test_gbnf_rule_construction,
    test_gbnf_token_validation_and_masking,
)
from tests.test_speculative import (
    test_speculative_proposal_and_verification,
    test_speculative_rollback_on_rejection,
)
from tests.test_resilience_matrix import (
    test_state_vault_durable_checkpoints,
    test_event_bus_pub_sub,
    test_task_descriptor_queue,
)
from tests.test_metal_realm import (
    test_metal_gate_availability,
    test_metal_gemm_dispatch_bounds,
    test_metal_realm_unsupported_gateways,
)
from tests.test_intel_realm import (
    test_intel_gate_availability,
    test_intel_gemm_dispatch_bounds,
    test_intel_realm_unsupported_gateways,
)
from tests.test_amd_realm import (
    test_amd_gate_availability,
    test_amd_gemm_dispatch_bounds,
    test_amd_realm_unsupported_gateways,
)
from tests.test_npu_realm import (
    test_npu_gate_availability,
    test_npu_gemm_dispatch_bounds,
    test_npu_realm_unsupported_gateways,
)
from tests.test_hardware_resilience import (
    test_non_positive_allocation_rejection,
    test_non_positive_dimension_gemm_rejection,
    test_self_healing_error_barriers,
)
from tests.test_quantized_inference import (
    test_gemm_q4_k_m_fused_parity,
    test_quantized_tensor_mapping,
)
from tests.test_legacy_quantization import (
    test_q4_0_parity,
    test_q4_1_parity,
    test_q5_0_parity,
    test_q5_1_parity,
)
from tests.test_q8_fp8_quantization import (
    test_fused_q8_0_parity,
    test_fused_q8_1_parity,
    test_fused_fp8_e4m3_parity,
    test_fused_fp8_e5m2_parity,
)
from tests.test_k_quants_3_5 import (
    test_fused_q3_k_s_parity,
    test_fused_q3_k_m_parity,
    test_fused_q3_k_l_parity,
    test_fused_q5_k_s_parity,
    test_fused_q5_k_m_parity,
)
from tests.test_k_quants_2_6 import (
    test_fused_q2_k_parity,
    test_fused_q6_k_parity,
)
from tests.test_gptq_awq_quantization import (
    test_gptq_4bit_known_value,
    test_gptq_8bit_known_value,
    test_awq_4bit_known_value,
    test_exl2_boundary,
    test_hqq_4bit_axis1_known_value,
    test_smoothquant_int8_known_value,
)
from tests.test_extreme_quants import (
    test_iq1_s_boundary,
    test_iq2_xxs_boundary,
    test_ternary_boundary,
)
from tests.test_quantization_hardening import (
    test_dequantizer_zero_and_null_bounds,
    test_gemm_invalid_dimensions_rejection,
    test_unrecognized_format_self_healing,
    test_nan_corrupt_weight_sanitization,
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
    test_supervisor_recovery_boundary,
)
from tests.test_huggingface import (
    test_hf_repo_parsing,
    test_hf_download_url_builder,
    test_hf_download_parameter_boundary,
    test_hf_subprocess_argument_safety,
    test_hf_pinned_download_admission,
)
from tests.test_swarm_cluster import (
    test_swarm_node_role,
    test_peer_node_metrics,
    test_peer_registry_and_load_balancer,
    test_swarm_cluster_task_dispatch,
)
from tests.test_swarm_protocol import (
    test_swarm_node_authentication,
    test_swarm_join_leave_heartbeat,
    test_remote_inference_dispatch,
)
from tests.test_new_paradigms_suite import (
    test_config_and_json,
    test_cli_flags,
    test_help_and_tui,
    test_skaldbrodir_doom_loop,
    test_thinking_redaction,
    test_tool_use_json,
    test_smart_failure_diagnostics,
    test_max_gate_boundary,
    test_experimental_paradigms,
)
from tests.test_ledger import TestLedger, run_case, record_skip


def main() raises:
    var ledger = TestLedger()
    run_case(ledger, "hardware.host_memory", test_host_memory_observations)
    run_case(ledger, "hardware.inference_memory_counts", test_native_memory_counts)
    run_case(ledger, "hardware.inference_memory_rejection", test_native_memory_rejection)
    run_case(ledger, "hardware.native_device_selection", test_native_device_selection)
    run_case(ledger, "hardware.planning_cli_rejection", test_native_planning_cli_rejection)

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
    run_case(ledger, "compute.dequantize_q4_k", test_dequantize_q4_k_m)
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
    run_case(
        ledger, "tokenizer.linear_bpe_perf", test_bpe_tokenizer_linear_perf
    )
    run_case(
        ledger, "memory.telemetry_and_recycling", test_mimir_well_telemetry
    )
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
    run_case(ledger, "rag.query_embedding", test_query_embedding_extraction)
    run_case(ledger, "rag.corpus_ingestion", test_corpus_ingestion)
    run_case(ledger, "rag.local_retrieval_prompt", test_end_to_end_rag_grounding)
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
    run_case(ledger, "npu.npu_gate_availability", test_npu_gate_availability)
    run_case(
        ledger, "npu.npu_gemm_dispatch_bounds", test_npu_gemm_dispatch_bounds
    )
    run_case(
        ledger,
        "npu.npu_realm_unsupported_gateways",
        test_npu_realm_unsupported_gateways,
    )
    print("")

    # --- GPU Descriptors and Unsupported Physical Gateways ---
    print("  [DOMAIN] GPU Descriptors and Unsupported Physical Gateways")
    print("  -----------------------------------------")
    run_case(ledger, "gpu.enum", test_gpu_realm_enum)
    run_case(ledger, "gpu.no_fabricated_detection", test_device_topology_gpus)
    run_case(ledger, "gpu.host_buffer_view", test_gpu_buffer_zero_copy)
    run_case(ledger, "gpu.unsupported_execution", test_gpu_gemm_parity)
    run_case(
        ledger,
        "gpu.discovery_status_classification",
        test_discovery_status_classification,
    )
    run_case(
        ledger, "gpu.physical_device_admission", test_physical_device_admission
    )
    run_case(
        ledger,
        "gpu.discovery_accumulation",
        test_topology_discovery_accumulation,
    )
    run_case(
        ledger, "gpu.stable_device_selection", test_topology_stable_selection
    )
    run_case(
        ledger, "gpu.resource_budget_accounting", test_cuda_budget_accounting
    )
    run_case(
        ledger,
        "gpu.resource_budget_transaction",
        test_cuda_budget_rejection_is_transactional,
    )
    run_case(
        ledger,
        "gpu.resource_budget_rollback",
        test_cuda_budget_overflow_and_rollback,
    )
    run_case(
        ledger,
        "gpu.resource_policy_admission",
        test_cuda_resource_policy_admission,
    )
    run_case(
        ledger,
        "gpu.cuda_gemm_plan_counts",
        test_cuda_gemm_plan_counts_and_launch,
    )
    run_case(
        ledger,
        "gpu.cuda_gemm_plan_shape_rejection",
        test_cuda_gemm_plan_shape_rejection,
    )
    run_case(
        ledger,
        "gpu.cuda_gemm_plan_abi_rejection",
        test_cuda_gemm_plan_overflow_and_abi_rejection,
    )
    run_case(
        ledger,
        "gpu.cuda_gemm_batch_transaction",
        test_cuda_gemm_batch_budget_transaction,
    )
    run_case(ledger, "gpu.cuda_gate_availability", test_cuda_gate_availability)
    run_case(
        ledger, "gpu.cuda_gemm_dispatch_bounds", test_cuda_gemm_dispatch_bounds
    )
    run_case(
        ledger,
        "gpu.cuda_realm_unsupported_gateways",
        test_cuda_realm_unsupported_gateways,
    )
    run_case(
        ledger, "gpu.metal_gate_availability", test_metal_gate_availability
    )
    run_case(
        ledger,
        "gpu.metal_gemm_dispatch_bounds",
        test_metal_gemm_dispatch_bounds,
    )
    run_case(
        ledger,
        "gpu.metal_realm_unsupported_gateways",
        test_metal_realm_unsupported_gateways,
    )
    run_case(
        ledger, "gpu.intel_gate_availability", test_intel_gate_availability
    )
    run_case(
        ledger,
        "gpu.intel_gemm_dispatch_bounds",
        test_intel_gemm_dispatch_bounds,
    )
    run_case(
        ledger,
        "gpu.intel_realm_unsupported_gateways",
        test_intel_realm_unsupported_gateways,
    )
    run_case(ledger, "gpu.amd_gate_availability", test_amd_gate_availability)
    run_case(
        ledger, "gpu.amd_gemm_dispatch_bounds", test_amd_gemm_dispatch_bounds
    )
    run_case(
        ledger,
        "gpu.amd_realm_unsupported_gateways",
        test_amd_realm_unsupported_gateways,
    )
    run_case(
        ledger,
        "gpu.resilience_allocation_rejection",
        test_non_positive_allocation_rejection,
    )
    run_case(
        ledger,
        "gpu.resilience_dimension_rejection",
        test_non_positive_dimension_gemm_rejection,
    )
    run_case(
        ledger,
        "gpu.resilience_error_barriers",
        test_self_healing_error_barriers,
    )
    print("")

    # --- Implemented CLI and Unsupported Boundaries ---
    print("  [DOMAIN] Implemented CLI and Unsupported Boundaries")
    print("  -----------------------------------------")
    run_case(ledger, "cli.modelfile_parser", test_modelfile_parser)
    run_case(ledger, "cli.manifest_store_restart", test_model_manifest_store)
    run_case(
        ledger, "cli.truthful_command_boundaries", test_cli_command_dispatch
    )
    run_case(
        ledger, "cli.repl_session_state", test_repl_session_and_slash_commands
    )
    run_case(ledger, "cli.flag_options_parser", test_cli_flag_options_parser)
    print("")

    # --- Compressed Format Scaffolds ---
    print("  [DOMAIN] Compressed Format Scaffolds")
    print("  -----------------------------------------")
    run_case(ledger, "quantization.enum", test_compressed_format_enum)
    run_case(
        ledger, "quantization.external_dequant_boundaries", test_dequantization_kernels
    )
    run_case(
        ledger,
        "quantization.fused_q4_k_m_parity",
        test_gemm_q4_k_m_fused_parity,
    )
    run_case(ledger, "quantization.fused_q4_0_parity", test_q4_0_parity)
    run_case(ledger, "quantization.fused_q4_1_parity", test_q4_1_parity)
    run_case(ledger, "quantization.fused_q5_0_parity", test_q5_0_parity)
    run_case(ledger, "quantization.fused_q5_1_parity", test_q5_1_parity)
    run_case(ledger, "quantization.fused_q8_0_parity", test_fused_q8_0_parity)
    run_case(ledger, "quantization.fused_q8_1_parity", test_fused_q8_1_parity)
    run_case(
        ledger, "quantization.fused_fp8_e4m3_parity", test_fused_fp8_e4m3_parity
    )
    run_case(
        ledger, "quantization.fused_fp8_e5m2_parity", test_fused_fp8_e5m2_parity
    )
    run_case(
        ledger, "quantization.fused_q3_k_s_parity", test_fused_q3_k_s_parity
    )
    run_case(
        ledger, "quantization.fused_q3_k_m_parity", test_fused_q3_k_m_parity
    )
    run_case(
        ledger, "quantization.fused_q3_k_l_parity", test_fused_q3_k_l_parity
    )
    run_case(
        ledger, "quantization.fused_q5_k_s_parity", test_fused_q5_k_s_parity
    )
    run_case(
        ledger, "quantization.fused_q5_k_m_parity", test_fused_q5_k_m_parity
    )
    run_case(ledger, "quantization.fused_q2_k_parity", test_fused_q2_k_parity)
    run_case(ledger, "quantization.fused_q6_k_parity", test_fused_q6_k_parity)
    run_case(
        ledger,
        "quantization.gptq_4bit_known_value",
        test_gptq_4bit_known_value,
    )
    run_case(
        ledger,
        "quantization.gptq_8bit_known_value",
        test_gptq_8bit_known_value,
    )
    run_case(
        ledger, "quantization.awq_4bit_known_value", test_awq_4bit_known_value
    )
    run_case(ledger, "quantization.exl2_boundary", test_exl2_boundary)
    run_case(
        ledger,
        "quantization.hqq_4bit_axis1_known_value",
        test_hqq_4bit_axis1_known_value,
    )
    run_case(
        ledger,
        "quantization.smoothquant_int8_known_value",
        test_smoothquant_int8_known_value,
    )
    run_case(ledger, "quantization.iq1_s_boundary", test_iq1_s_boundary)
    run_case(
        ledger, "quantization.iq2_xxs_boundary", test_iq2_xxs_boundary
    )
    run_case(
        ledger,
        "quantization.ternary_boundary",
        test_ternary_boundary,
    )
    run_case(
        ledger,
        "quantization.hardening_zero_and_null_bounds",
        test_dequantizer_zero_and_null_bounds,
    )
    run_case(
        ledger,
        "quantization.hardening_invalid_dimensions",
        test_gemm_invalid_dimensions_rejection,
    )
    run_case(
        ledger,
        "quantization.hardening_unrecognized_format",
        test_unrecognized_format_self_healing,
    )
    run_case(
        ledger,
        "quantization.hardening_nan_sanitization",
        test_nan_corrupt_weight_sanitization,
    )
    run_case(
        ledger,
        "quantization.tensor_mapping_metadata",
        test_quantized_tensor_mapping,
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
    run_case(ledger, "server.http_response_framing", test_http_response_framing)
    run_case(ledger, "server.openai_rest_gateway", test_openai_rest_gateway)
    print("")

    # --- Local Resilience & Concurrency Matrix ---
    print("  [DOMAIN] Local Resilience & Concurrency Matrix")
    print("  -----------------------------------------")
    run_case(ledger, "resilience.error_guard", test_error_guard)
    run_case(ledger, "resilience.state_vault_marker", test_state_vault)
    run_case(
        ledger,
        "resilience.durable_state_vault",
        test_state_vault_durable_checkpoints,
    )
    run_case(ledger, "resilience.event_bus_marker", test_event_bus)
    run_case(ledger, "resilience.event_bus_pub_sub", test_event_bus_pub_sub)
    run_case(ledger, "resilience.thread_pool_stub", test_thread_pool)
    run_case(
        ledger,
        "resilience.task_descriptor_queue",
        test_task_descriptor_queue,
    )
    run_case(
        ledger,
        "resilience.supervisor_recovery_unsupported",
        test_supervisor_recovery_boundary,
    )
    print("")

    # --- Hugging Face String Helpers and Unsupported Download ---
    print("  [DOMAIN] Hugging Face Download Admission and Process Safety")
    print("  -----------------------------------------")
    run_case(ledger, "huggingface.tag_parser", test_hf_repo_parsing)
    run_case(ledger, "huggingface.url_builder", test_hf_download_url_builder)
    run_case(ledger, "huggingface.argv_safety", test_hf_subprocess_argument_safety)
    run_case(ledger, "huggingface.pinned_admission", test_hf_pinned_download_admission)
    run_case(ledger, "cli.cuda_chat_admission", test_cuda_chat_admission)
    run_case(
        ledger,
        "huggingface.download_parameter_boundary",
        test_hf_download_parameter_boundary,
    )
    print("")

    # --- Swarm Protocol & Distributed Mesh Mesh Matrix ---
    print("  [DOMAIN] Swarm Protocol & Distributed Mesh Matrix")
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
    run_case(
        ledger,
        "swarm.node_authentication",
        test_swarm_node_authentication,
    )
    run_case(
        ledger,
        "swarm.join_leave_heartbeat",
        test_swarm_join_leave_heartbeat,
    )
    run_case(
        ledger,
        "swarm.remote_inference_dispatch",
        test_remote_inference_dispatch,
    )
    print("")

    # --- New System Paradigms, Safety Protocols and Framework Controls ---
    print("  [DOMAIN] System Paradigms, Safety Protocols and Framework Controls")
    print("  -----------------------------------------")
    run_case(ledger, "paradigms.config_and_json", test_config_and_json)
    run_case(ledger, "paradigms.cli_flags", test_cli_flags)
    run_case(ledger, "paradigms.help_and_tui", test_help_and_tui)
    run_case(ledger, "paradigms.skaldbrodir_doom_loop", test_skaldbrodir_doom_loop)
    run_case(ledger, "paradigms.thinking_redaction", test_thinking_redaction)
    run_case(ledger, "paradigms.tool_use_json", test_tool_use_json)
    run_case(ledger, "paradigms.failure_diagnostics", test_smart_failure_diagnostics)
    run_case(ledger, "paradigms.max_gate_boundary", test_max_gate_boundary)
    run_case(ledger, "paradigms.experimental_paradigms", test_experimental_paradigms)
    print("")

    # --- ONNX Protobuf & Operator Dispatcher Subset ---
    print("  [DOMAIN] ONNX Protobuf & Operator Dispatcher Subset")
    print("  -----------------------------------------")
    run_case(ledger, "onnx.recognized_operators", test_onnx_recognized_operators)
    run_case(ledger, "onnx.model_seer", test_onnx_seer_header_validation)
    print("")

    # --- EXL2 Descriptor and Unsupported Runtime Boundary ---
    print("  [DOMAIN] EXL2 Descriptor and Unsupported Runtime Boundary")
    print("  -----------------------------------------")
    run_case(ledger, "exl2.cuda_contract", test_exl2_cuda_contract_validation)
    run_case(ledger, "exl2.model_seer", test_exl2_model_seer)
    print("")

    # --- llama.cpp Unsupported Compatibility Boundary ---
    print("  [DOMAIN] llama.cpp Unsupported Compatibility Boundary")
    print("  -----------------------------------------")
    run_case(ledger, "llama_cpp_cli.subcommands", test_llama_cpp_subcommands)
    run_case(ledger, "llama_cpp_cli.arg_parsing", test_llama_cpp_arg_parsing)
    print("")

    # --- GBNF Grammar Parser & Automaton ---
    print("  [DOMAIN] GBNF Grammar Parser & Automaton")
    print("  -----------------------------------------")
    run_case(ledger, "gbnf.rule_construction", test_gbnf_rule_construction)
    run_case(
        ledger,
        "gbnf.token_validation_masking",
        test_gbnf_token_validation_and_masking,
    )
    print("")

    # --- Speculative Decoding Engine ---
    print("  [DOMAIN] Speculative Decoding Engine")
    print("  -----------------------------------------")
    run_case(
        ledger,
        "speculative.proposal_verification",
        test_speculative_proposal_and_verification,
    )
    run_case(
        ledger,
        "speculative.rejection_rollback",
        test_speculative_rollback_on_rejection,
    )
    print("")

    run_case(ledger, "sampling.strict_syntax", test_sampling_syntax)
    run_case(ledger, "sampling.config_rejection", test_sampling_config_rejection)
    run_case(ledger, "sampling.config_updates", test_sampling_config_updates)
    run_case(ledger, "upload.staging_bounds", test_upload_staging_bounds)
    run_case(ledger, "upload.host_admission", test_upload_host_admission)
    run_case(ledger, "cgroup.paths", test_cgroup_paths)
    run_case(ledger, "cgroup.hierarchy", test_cgroup_hierarchy)
    run_case(ledger, "cgroup.rejection", test_cgroup_rejection)
    run_case(ledger, "control.deadline", test_generation_deadline)
    run_case(ledger, "control.admission", test_generation_control_rejection)
    run_case(ledger, "control.sigint", test_generation_sigint)
    run_case(ledger, "local_service.json", test_local_json)
    run_case(ledger, "local_service.http", test_local_http)
    run_case(ledger, "local_service.request", test_local_generation_request)
    run_case(ledger, "local_service.c_paths", test_local_path_bounds)
    ledger.finish(171)
