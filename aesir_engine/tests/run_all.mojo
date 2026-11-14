# tests/run_all.mojo
# The Grand Proving: Master Test Runner for Project Aesir
#
# Invokes every verification rite in sequence.
# Run with (from the repository root; the FFI shims must be staged and
# linked exactly as in scripts/launch.py, and the -Xlinker flags must
# precede the source file or the JIT cannot resolve the FFI symbols):
#   staging="$(mktemp -d)" && cc -std=c11 -fPIC -shared aesir_engine/hailo10h_stub.c -o "$staging/libaesir_hailo10h.so" && cc -std=c11 -O2 -fPIC -shared aesir_engine/thread_par.c -o "$staging/libaesir_par.so" -lpthread && cc -std=c11 -O2 -fPIC -shared aesir_engine/hip_memory_shim.c -o "$staging/libaesir_hip.so" -ldl && cc -std=c11 -O2 -fPIC -shared aesir_engine/vulkan_context_shim.c aesir_engine/vulkan_buffer_shim.c -o "$staging/libaesir_vulkan.so" -ldl && cc -std=c11 -O2 -fPIC -shared aesir_engine/zero_copy_shim.c -o "$staging/libaesir_zc.so" -ldl && pixi run mojo run -I . --target-accelerator gfx1151 -Xlinker "-L$staging" -Xlinker -laesir_hailo10h -Xlinker -laesir_par -Xlinker -laesir_hip -Xlinker -laesir_vulkan -Xlinker -laesir_zc aesir_engine/tests/run_all.mojo
#
# Backend note (A-028 target-flag audit): gfx1151 is the AMD ROCm compile
# target for the Z13 host (Radeon 8060S, Strix Halo) -- zero NVIDIA flags.
# Host code executes on CPU; since A-029 the gpu.mojo_native_* cases
# additionally execute Mojo-native kernels on the GPU itself when a
# HIP device is present (device-execution evidence in
# docs/AESIR_Z13_MOJO_GPU_DECISION.md). On an
# NVIDIA host, substitute the NVIDIA CUDA target sm_89 in the same position.
# scripts/build_matrix.sh runs the named cpu / amd entries of this suite.
#
# Known issue (pre-existing, proven identical on the unmodified base
# tree in both JIT and AOT modes): the run currently segfaults inside
# the rag.cosine_similarity case after 74 passing cases; that case
# passes in isolation on base and fixed trees alike. This is a
# separate defect from the LLVM split-operator compiler crash fixed
# on platform/llvm-split-crash-fix (see llvm-crash-checkpoint/NOTES.md).

from tests.test_compute import (
    test_gemm,
    test_gemm_f16_gpgpu_vector_cpu_fallback,
    test_flash_attention,
    test_silu,
    test_geglu,
    test_dequantize_q4_k_m,
)
from tests.test_gguf import test_gguf_parsing, test_ggml_type
from tests.test_tokenizer import test_tokenizer, test_byte_bpe_merge_baseline, test_byte_bpe_merge_interface, test_byte_bpe_merge_adversarial, test_byte_bpe_merge_integration, test_byte_bpe_merge_negative_scores, test_unicode_normalization_baseline, test_unicode_normalization_interface, test_unicode_normalization_integration, test_unicode_normalization_adversarial, test_invalid_utf8_rejection, test_invalid_utf8_adversarial, test_invalid_utf8_integration, test_invalid_utf8_single_byte_sweep
from tests.test_tokenizer_edge_a050 import test_tokenizer_edge_empty_and_bos, test_tokenizer_edge_no_vocab_fallback, test_tokenizer_edge_unicode_emoji, test_tokenizer_edge_control_tokens, test_tokenizer_edge_invalid_utf8, test_tokenizer_edge_oversized
from tests.test_local_protocol import test_local_json, test_local_http, test_local_http_bounds, test_local_http_framing, test_local_generation_request, test_local_path_bounds, test_ollama_sampling_bounds, test_gemma_tool_protocol
from tests.test_local_transport_ownership import test_owned_fd_transfer_release, test_socket_admission_rejection, test_socketpair_request_transport, test_request_transport_adversarial
from tests.test_generation_control import test_generation_deadline, test_generation_control_rejection, test_generation_sigint
from tests.test_cgroup_memory import test_cgroup_paths, test_cgroup_hierarchy, test_cgroup_rejection
from tests.test_upload_admission import test_upload_staging_bounds, test_upload_host_admission
from tests.test_sampling_config import test_sampling_syntax, test_sampling_config_rejection, test_sampling_config_updates
from tests.test_cuda_chat_admission import (
    test_cuda_chat_admission,
    test_cuda_model_switch_syntax,
)
from tests.test_native_planning import test_host_memory_observations, test_native_memory_counts, test_native_memory_rejection, test_native_device_selection, test_automatic_context_sequence, test_native_planning_cli_rejection
from tests.test_text_admission import test_persisted_text_admission
from tests.test_gemma4_profile import test_gemma4_profiles
from tests.test_model_registry import test_model_architecture_registry
from tests.test_inference import (
    test_iq_embedding_lookup,
    test_forward_pass,
    test_generation_stop_policy,
    test_unsupported_runtime_config,
    test_prompt_byte_bound,
    test_greedy_tie_policy,
    test_greedy_tie_adversarial,
    test_temperature_distribution_oracle,
    test_temperature_sampling_integration,
    test_temperature_sampling_adversarial,
    test_top_k_boundary_semantics,
    test_top_k_sampling_integration,
    test_top_k_adversarial,
)
from tests.test_kv_cache import test_kv_cache
from tests.test_checked_span import test_checked_span
from tests.test_stream_reader import test_stream_reader
from tests.test_expert_cache import test_expert_cache
from tests.test_dense_residency import test_dense_residency
from tests.test_rune_tensor_layout import test_rune_tensor_layout
from tests.test_rmsnorm_interface import test_rmsnorm_interface
from tests.test_rmsnorm_reference import test_rmsnorm_reference
from tests.test_rmsnorm_integration import test_rmsnorm_inference_integration
from tests.test_rmsnorm_adversarial import test_rmsnorm_adversarial
from tests.test_rope_interface import test_rope_interface
from tests.test_rope_reference import test_rope_reference
from tests.test_rope_integration import test_rope_integration
from tests.test_rope_adversarial import test_rope_adversarial
from tests.test_attention_interface import test_attention_interface
from tests.test_attention_reference import test_attention_reference
from tests.test_attention_integration import test_attention_integration
from tests.test_attention_adversarial import test_attention_adversarial
from tests.test_gguf_metadata_types import (
    test_gguf_metadata_type_rejection,
    test_gguf_metadata_type_integration,
    test_gguf_tensor_directory_baseline,
    test_gguf_tensor_directory_interface,
    test_gguf_tensor_directory_adversarial,
    test_gguf_tensor_directory_integration,
    test_gguf_tensor_directory_pool_adversarial,
)
from tests.test_gguf_version_interface import (
    test_gguf_version_interface,
    test_gguf_version_reference,
    test_gguf_version_integration,
    test_gguf_header_adversarial,
)
from tests.test_mimir_well import (
    test_mimir_well_allocation,
    test_mimir_well_allocation_bounds,
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
    test_topology_probe_failure_notes,
)
from tests.test_cuda_resource_budget import (
    test_cuda_budget_accounting,
    test_cuda_budget_rejection_is_transactional,
    test_cuda_budget_overflow_and_rollback,
    test_cuda_allocation_tracker_adversarial,
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
    test_amd_hip_device_gate,
    test_amd_hip_properties_parser,
    test_amd_realm_unsupported_gateways,
    test_hip_malloc_free_round_trip,
    test_hip_alloc_rejection,
    test_hip_malloc_managed_round_trip,
    test_hip_mem_get_info_accounting,
    test_hip_no_leak_1000,
    test_hip_sync_oracle_round_trip,
    test_hip_stream_async_round_trip,
    test_hip_stream_overlap_smoke,
    test_hip_event_timing,
    test_hip_stream_rejection,
)
from tests.test_vulkan_context import (
    test_vulkan_context_create,
    test_vulkan_taxonomy_mapping,
    test_vulkan_forced_failure_taxonomy,
    test_vulkan_context_rejection,
)
from tests.test_arena_allocator import (
    test_arena_reset_semantics,
    test_arena_rejection,
    test_arena_fragmentation_stress,
    test_arena_pool_device,
    test_arena_shim_registry_over_4096,
)
from tests.test_weight_residency import (
    test_weight_residency_accounting_rules,
    test_weight_residency_mapping_accounting,
    test_weight_residency_gpu_visibility,
    test_weight_residency_no_device_copy,
)
from tests.test_vulkan_buffers import (
    test_vulkan_buffer_alignment_rules,
    test_vulkan_buffer_round_trip,
    test_vulkan_buffer_alloc_rejection,
    test_vulkan_buffer_no_leak,
)
from tests.test_vulkan_dispatch import (
    test_vulkan_dispatch_vec_add_oracle,
    test_vulkan_dispatch_rejection,
    test_vulkan_dispatch_no_leak,
)
from tests.test_spirv_pipeline_a055 import (
    test_spirv_pipeline_manifest,
    test_spirv_pipeline_hashes_recorded,
    test_spirv_pipeline_header_embedded,
    test_spirv_pipeline_no_runtime_fetch,
    test_spirv_pipeline_toolchain_recorded,
)
from tests.test_vulkan_q8_gemv import (
    test_vulkan_q8_gemv_oracle_parity,
    test_vulkan_q8_gemv_known_value,
    test_vulkan_q8_gemv_engine_crosscheck,
    test_vulkan_q8_gemv_rejection,
    test_vulkan_q8_gemv_dispatch_evidence,
)
from tests.test_vulkan_attention_a062 import (
    test_vulkan_attn_decode_oracle_parity,
    test_vulkan_attn_decode_known_value,
    test_vulkan_attn_decode_gqa_fixture,
    test_vulkan_attn_decode_rejection,
    test_vulkan_attn_decode_dispatch_evidence,
)
from tests.test_vulkan_sampling_a063 import (
    test_vulkan_sampling_greedy_oracle_parity,
    test_vulkan_sampling_greedy_tie_policy,
    test_vulkan_sampling_sample_oracle_exact,
    test_vulkan_sampling_temperature_distribution,
    test_vulkan_sampling_rejection,
    test_vulkan_sampling_dispatch_evidence,
)
from tests.test_gpu_weight_residency_a064 import (
    test_gpu_weight_residency_single,
    test_gpu_weight_residency_no_reupload,
    test_gpu_weight_residency_cpu_shared,
    test_gpu_weight_residency_multi_tensor,
    test_gpu_weight_residency_rejection,
)
from tests.test_vulkan_layer_a065 import (
    test_vulkan_layer_oracle_parity,
    test_vulkan_layer_known_value,
    test_vulkan_layer_standalone_index,
    test_vulkan_layer_rejection,
    test_vulkan_layer_dispatch_evidence,
)
from tests.test_vulkan_decode_a066 import (
    test_vulkan_decode_kv_append_parity,
    test_vulkan_decode_strided_attention_parity,
    test_vulkan_decode_token_exact,
    test_vulkan_decode_rejection,
)
from tests.test_vulkan_real_model_a067 import (
    test_vulkan_real_model_sanitize_policy,
    test_vulkan_real_model_rope_permutation,
    test_vulkan_real_model_fixture_config,
    test_vulkan_real_model_teacher_forcing,
    test_vulkan_real_model_generation,
    test_vulkan_real_model_dispatch_evidence,
    test_vulkan_real_model_rejection,
)
from tests.test_vulkan_prefill_a069 import (
    test_vulkan_chunked_prefill_cpu_oracle_parity,
    test_vulkan_chunked_prefill_identical_to_unchunked,
    test_vulkan_chunked_prefill_causal_isolation,
    test_vulkan_chunked_prefill_rope_global_positions,
    test_vulkan_chunked_prefill_kv_append_chunk_slots,
    test_vulkan_chunked_prefill_rejection,
    test_vulkan_chunked_prefill_dispatch_and_bounds,
)
from tests.test_vulkan_async_a071 import (
    test_vulkan_async_token_identity,
    test_vulkan_async_no_wait_idle,
    test_vulkan_async_timeline_sane,
    test_vulkan_async_dispatch_queueing,
    test_vulkan_async_rejection,
    test_vulkan_async_dispatch_evidence,
)
from tests.test_accum_policy_a075 import (
    test_accum_policy_table_completeness,
    test_accum_policy_table_uniform_fp32,
    test_accum_policy_dot_error_k_scaling,
    test_accum_policy_logit_gap_battery,
    test_accum_policy_norm_mass_attention,
    test_accum_policy_emulation_invariants,
)
from tests.test_gpu_soak_a077 import (
    test_gpu_soak_slope_flat_and_leak,
    test_gpu_soak_verdict_precedence,
    test_gpu_soak_tally_accounting,
    test_gpu_soak_live_rss_reader,
    test_gpu_soak_device_burst,
)
from tests.test_gpu_fuzz_a078 import (
    test_gpu_fuzz_seed_replay,
    test_gpu_fuzz_case_coverage,
    test_gpu_fuzz_verdict_classifier,
    test_gpu_fuzz_synthetic_row_battery,
    test_gpu_fuzz_sampling_greedy,
    test_gpu_fuzz_sampling_temperature,
    test_gpu_fuzz_real_model_random_prompts,
)
from tests.test_device_lost_a079 import (
    test_device_lost_taxonomy,
    test_device_lost_control_parity,
    test_device_lost_failover_midrun,
    test_device_lost_fail_closed_state_intact,
    test_device_lost_edges_and_repeat,
    test_device_lost_watchdog_bound,
    test_device_lost_live_shim_fail_closed,
)
from tests.test_equivalence_gate_a080 import (
    test_equivalence_classifier_table,
    test_equivalence_battery_aggregation,
    test_equivalence_regression_blocks,
    test_equivalence_gate_script_contract,
    test_equivalence_sampling_parity,
    test_equivalence_real_model_parity,
)
from tests.test_gpu_pressure_a076 import (
    test_gpu_pressure_classification,
    test_gpu_pressure_gpu_route_baseline,
    test_gpu_pressure_squeeze_spill_refuse,
    test_gpu_pressure_bounded_degradation,
    test_gpu_pressure_recovery,
    test_gpu_pressure_live_and_log_bound,
    test_gpu_pressure_device_buffer,
)
from tests.test_spillover_policy_a102 import (
    test_spillover_all_fit_gpu,
    test_spillover_capacity_spill_order,
    test_spillover_nonspillable_refusal_atomic,
    test_spillover_spill_cap_bound,
    test_spillover_assist_evidence_gate,
    test_spillover_log_reproducible,
    test_spillover_device_execution,
)
from tests.test_fairness_a105 import (
    test_fairness_equal_share,
    test_fairness_weighted_share,
    test_fairness_no_starvation_adversarial,
    test_fairness_idle_no_hoard,
    test_fairness_single_model_throughput,
    test_fairness_governor_pressure,
    test_fairness_log_reproducible,
    test_fairness_device_execution,
)
from tests.test_telemetry_a106 import (
    test_telemetry_live_bounds,
    test_telemetry_cpu_util_parser,
    test_telemetry_external_match,
    test_telemetry_placement_decisions_exposed,
    test_telemetry_clamp_and_tolerance,
    test_telemetry_no_device_graceful,
    test_telemetry_gpu_memory_reacts,
    test_telemetry_cpu_util_live_window,
)
from tests.test_vulkan_batch_a072 import (
    test_vulkan_continuous_batch_four_match_single,
    test_vulkan_continuous_batch_heterogeneous,
    test_vulkan_continuous_batch_dynamic_admission,
    test_vulkan_continuous_batch_isolation,
    test_vulkan_continuous_batch_rejection,
    test_vulkan_continuous_batch_single_slot_serial,
)
from tests.test_vulkan_gemm_a068 import (
    test_vulkan_prefill_gemm_oracle_parity,
    test_vulkan_prefill_gemm_known_value,
    test_vulkan_prefill_gemm_f32_parity,
    test_vulkan_prefill_gemm_batch_independence,
    test_vulkan_prefill_gemm_rejection,
    test_vulkan_prefill_gemm_dispatch_evidence,
)
from tests.test_cpu_assist_a070 import (
    test_cpu_assist_stats_accounting,
    test_cpu_assist_policy_verdicts,
    test_cpu_assist_stitch_equivalence,
    test_cpu_assist_sanitize_policy,
    test_cpu_assist_inventory_completeness,
    test_cpu_assist_stats_absent_model,
)
from tests.test_vulkan_q6k_q5k_gemv import (
    test_vulkan_q6k_q5k_oracle_parity,
    test_vulkan_q6k_q5k_known_value,
    test_vulkan_q6k_q5k_engine_crosscheck,
    test_vulkan_q6k_q5k_rejection,
    test_vulkan_q6k_q5k_dispatch_evidence,
)
from tests.test_vulkan_iq_gemv import (
    test_vulkan_iq_gemv_oracle_parity,
    test_vulkan_iq_gemv_known_value,
    test_vulkan_iq_gemv_engine_crosscheck,
    test_vulkan_iq_gemv_rejection,
    test_vulkan_iq_gemv_dispatch_evidence,
)
from tests.test_vulkan_elementwise_softmax_a061 import (
    test_vulkan_elementwise_oracle_parity,
    test_vulkan_elementwise_known_value,
    test_vulkan_softmax_oracle_parity,
    test_vulkan_softmax_adversarial,
    test_vulkan_elementwise_softmax_rejection,
    test_vulkan_elementwise_softmax_dispatch_evidence,
)
from tests.test_vulkan_q4k_gemv_a057 import (
    test_vulkan_q4k_gemv_oracle,
    test_vulkan_q4k_gemv_rejection,
    test_vulkan_q4k_gemv_no_leak,
)
from tests.test_vulkan_rmsnorm_rope_a060 import (
    test_vulkan_rmsnorm_oracle_parity,
    test_vulkan_rmsnorm_known_value,
    test_vulkan_rope_oracle_parity,
    test_vulkan_rope_known_properties,
    test_vulkan_rmsnorm_rope_rejection,
    test_vulkan_rmsnorm_rope_dispatch_evidence,
)
from tests.test_zero_copy import (
    test_zero_copy_hip_cpu_write_gpu_read,
    test_zero_copy_hip_gpu_write_cpu_read,
    test_zero_copy_vulkan_cpu_write_gpu_read,
    test_zero_copy_rejection,
    test_zero_copy_no_leak,
)
from tests.test_memory_budget import (
    test_budget_cap_honoured_measured,
    test_budget_refusal_fail_closed,
    test_budget_spill_degradation,
    test_budget_configurability,
    test_budget_accounting_baseline,
    test_budget_live_meminfo_pressure,
)
from tests.test_mojo_gpu_target import (
    test_mojo_native_vec_add_oracle,
    test_mojo_native_gemm_oracle,
    test_mojo_native_rejection,
)
from tests.test_hip_q8_gemv_a082 import (
    test_hip_q8_gemv_oracle_parity,
    test_hip_q8_gemv_known_value,
    test_hip_q8_gemv_engine_crosscheck,
    test_hip_q8_gemv_rejection,
    test_hip_q8_gemv_dispatch_evidence,
)
from tests.test_hip_q4k_gemv_a083 import (
    test_hip_q4k_gemv_oracle,
    test_hip_q4k_gemv_rejection,
    test_hip_q4k_gemv_no_leak,
)
from tests.test_hip_attn_norms_a084 import (
    test_hip_attn_norms_rmsnorm_oracle,
    test_hip_attn_norms_rope_oracle,
    test_hip_attn_norms_attention_oracle,
    test_hip_attn_norms_rejection,
    test_hip_attn_norms_dispatch_evidence,
)
from tests.test_rocm_repro_a087 import (
    test_rocm_repro_pin_table,
    test_rocm_repro_convergence_accepts,
    test_rocm_repro_convergence_rejects,
    test_rocm_repro_script_contract,
    test_rocm_repro_script_sync,
)
from tests.test_kv_unified import (
    test_kv_unified_layout,
    test_kv_unified_bounds,
    test_kv_unified_gpu_write_cpu_read,
    test_kv_unified_cpu_write_gpu_read,
    test_kv_unified_append_roundtrip,
    test_kv_unified_vulkan_shared,
)
from tests.test_buffer_ownership import (
    test_hip_buffer_ownership_adversarial,
    test_vulkan_buffer_ownership_adversarial,
    test_zero_copy_buffer_ownership_adversarial,
    test_xrt_bo_ownership_contract,
)
from tests.test_thread_placement import (
    test_thread_placement_list_parse,
    test_thread_placement_topology_build,
    test_thread_placement_map_spread,
    test_thread_placement_map_pack_ccd,
    test_thread_placement_reject,
    test_thread_placement_live_affinity,
)
from tests.test_thread_scaling import (
    test_thread_scaling_default_policy,
    test_thread_scaling_cache_probes,
    test_thread_scaling_knob_readback,
    test_thread_scaling_stale_until_refresh,
    test_thread_scaling_min_work_cached,
    test_thread_scaling_dispatch_identity,
)
from tests.test_structured_errors import (
    test_structured_errors_mapping_table,
    test_structured_errors_fault_injection,
    test_structured_errors_real_paths,
    test_structured_errors_translation,
    test_structured_errors_vulkan_cpu_consistency,
)
from tests.test_hip_errors_a089 import (
    test_hip_errors_mapping_table,
    test_hip_errors_fault_injection,
    test_hip_errors_fallback_and_success,
    test_hip_errors_gateway_consistency,
    test_hip_errors_real_paths,
)
from tests.test_pipeline_overlap_a101 import (
    test_pipeline_overlap_pairwise_math,
    test_pipeline_overlap_wall_and_delta,
    test_pipeline_overlap_trace_line,
    test_pipeline_overlap_acceptance,
    test_pipeline_overlap_plan_gating,
    test_pipeline_overlap_filed_trace,
)
from tests.test_failure_replan_a103 import (
    test_replan_gpu_loss_onto_survivors,
    test_replan_npu_loss_uses_survivors,
    test_replan_drill_gpu_loss_completes_exact,
    test_replan_drill_npu_loss_completes_exact,
    test_replan_cpu_loss_fails_closed,
    test_replan_second_failure_fails_closed,
    test_replan_edges_and_summary,
)
from tests.test_big_model_placement_a104 import (
    test_big_model_geometry,
    test_big_model_kv_accounting,
    test_big_model_split_half,
    test_big_model_split_edges,
    test_big_model_pool_gate,
    test_big_model_pressure_budget,
)
from tests.test_npu_realm import (
    test_npu_probe_absence,
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
from tests.test_q8_0_gemv_simd import (
    test_q8_0_gemv_simd_known_value,
    test_q8_0_gemv_simd_parity,
    test_q8_0_gemv_multirow_regression,
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
from tests.test_k_dequant_simd_a040 import (
    test_k_dequant_simd_q4_k_parity,
    test_k_dequant_simd_q5_k_parity,
    test_k_dequant_simd_q6_k_parity,
)
from tests.test_k_quants_2_6 import (
    test_fused_q2_k_parity,
    test_fused_q6_k_parity,
)
from tests.test_gptq_awq_quantization import (
    test_gptq_4bit_known_value,
    test_gptq_8bit_known_value,
    test_awq_4bit_known_value,
    test_exl2_mixedbit_known_value,
    test_hqq_4bit_axis1_known_value,
    test_smoothquant_int8_known_value,
)
from tests.test_extreme_quants import (
    test_iq1_s_known_value,
    test_iq2_s_known_value,
    test_iq2_xs_known_value,
    test_iq2_xxs_known_value,
    test_iq3_s_known_value,
    test_iq3_xxs_known_value,
    test_tq1_0_known_value,
)
from tests.test_iq_simd_parity import (
    test_iq_simd_parity_iq1_m,
    test_iq_simd_parity_iq1_s,
    test_iq_simd_parity_iq2_s,
    test_iq_simd_parity_iq2_xs,
    test_iq_simd_parity_iq2_xxs,
    test_iq_simd_parity_iq3_s,
    test_iq_simd_parity_iq3_xxs,
    test_iq_simd_parity_iq4_nl,
    test_iq_simd_parity_iq4_xs,
)
from tests.test_prefill_batching import (
    test_prefill_batching_policy,
    test_prefill_batching_dense_range_parity,
    test_prefill_batching_dense_public_parity,
    test_prefill_batching_q8_range_parity,
    test_prefill_batching_q4_0_public_parity,
)
from tests.test_chat_template_goldens_a051 import (
    test_chat_template_golden_chatml,
    test_chat_template_golden_llama3,
    test_chat_template_golden_llama2,
    test_chat_template_golden_gemma,
    test_chat_template_golden_family_routing,
)
from tests.test_long_context_a052 import (
    test_long_context_growth_account,
    test_long_context_session_cap_verdict,
    test_long_context_depths_patterns,
    test_long_context_probe_grading,
    test_long_context_kv_growth_execution,
    test_long_context_needle_probes,
)
from tests.test_state_storage_a053 import (
    test_storage_z13_autosave_generations,
    test_storage_z13_state_vault_disk,
    test_storage_z13_catalog_restart,
    test_storage_z13_conversation_snapshot,
)
from tests.test_fused_attention_a043 import (
    test_gqa_simd_reference_parity,
    test_gqa_simd_dyadic_bitwise,
    test_gqa_simd_tail_parity,
    test_gqa_simd_modifiers_parity,
    test_gqa_simd_long_parity,
)
from tests.test_quantization_hardening import (
    test_dequantizer_zero_and_null_bounds,
    test_gemm_invalid_dimensions_rejection,
    test_unrecognized_format_self_healing,
    test_nan_corrupt_weight_sanitization,
)
from tests.test_quantization_autotuner import (
    test_quantization_format_metadata,
    test_measured_quantized_gemm_autotuner,
)
from tests.test_cli import (
    test_modelfile_parser,
    test_model_manifest_store,
    test_catalog_schema_interface,
    test_catalog_schema_unit_evidence,
    test_blob_identity_interface,
    test_blob_identity_unit_evidence,
    test_atomic_registration_unit_evidence,
    test_cli_command_dispatch,
    test_repl_session_and_slash_commands,
    test_cli_flag_options_parser,
    test_cli_enum_flag_validation,
    test_parse_int_strict,
    test_parse_duration_seconds_strict,
    test_model_reference_traversal_fail_closed,
)
from tests.test_doctor import (
    test_doctor_observations,
    test_doctor_readiness_policy,
    test_doctor_disk_fallback_issue,
    test_doctor_listener_probe_issue,
)
from tests.test_thermal_power import (
    test_thermal_parsers_and_formats,
    test_thermal_tolerance_tracking,
    test_thermal_lines_fixture,
    test_thermal_live_this_machine,
)
from tests.test_hardware_census import (
    test_kfd_gfx_parser,
    test_os_release_and_uevent_parsers,
    test_sysfs_number_parsers,
    test_census_lines_fixture,
    test_live_census_this_machine,
    test_cuda_absent_is_not_an_error,
)
from tests.test_backend_registry import (
    test_backend_registry_all_present,
    test_backend_registry_absent_combinations,
    test_backend_registry_degraded_and_software_vulkan,
    test_backend_registry_parsers,
)
from tests.test_device_policy import (
    test_device_policy_accelerator_first_all_present,
    test_device_policy_gpu_backend_fallback,
    test_device_policy_cpu_spillover_and_none,
    test_device_policy_override,
    test_device_policy_npu_proven_path,
    test_device_policy_deterministic_log,
)
from tests.test_backend_config import (
    test_backend_config_vocabulary,
    test_backend_config_file_and_cli_surface,
    test_backend_config_explicit_resolution,
    test_backend_config_absent_fail_closed,
    test_backend_config_npu_honesty_gate,
    test_backend_config_auto_order,
)
from tests.test_gpu_winner_a086 import (
    test_gpu_winner_pending_state,
    test_gpu_winner_hip_wins,
    test_gpu_winner_vulkan_wins,
    test_gpu_winner_invalid_verdicts_fail_closed,
    test_gpu_winner_probe_only_never_placed,
    test_gpu_winner_determinism_and_clear,
)
from tests.test_part_iv_gate_a108 import (
    test_gate_in_flight_rows_honest,
    test_gate_negative_verdicts_present,
    test_gate_no_unexplained_rows,
    test_gate_planner_scope_matches_planner,
    test_gate_summary_names_scope,
    test_gate_verdict_table_complete,
)
from tests.test_oracle_pins_a110 import (
    test_pin_build_hash_forms,
    test_pin_mark_judged_success,
    test_pin_malformed_hash_blocks,
    test_pin_missing_each_blocks,
    test_pin_registry_file_in_repo,
    test_pin_registry_judged_rows_pinned,
    test_pin_registry_unpinned_example_unjudged,
)
from tests.test_near_tie_gate_a111 import (
    test_near_tie_band_constants,
    test_near_tie_band_interior,
    test_near_tie_band_line,
    test_near_tie_comparator_precedence,
    test_near_tie_exact_step,
    test_near_tie_gap_edge,
    test_near_tie_invalid_records_refused,
    test_near_tie_matches_prefill_grade,
    test_near_tie_rank_edge,
    test_near_tie_row_verdicts,
    test_near_tie_sequence_verdicts,
)
from tests.test_placement_planner_a100 import (
    test_planner_standard_fixtures,
    test_planner_prefill_variants,
    test_planner_gemm_thresholds,
    test_planner_decode_and_sampling,
    test_planner_honesty_and_fallback,
    test_planner_cost_tables_and_lines,
)
from tests.test_placement_regression_a107 import (
    test_battery_planner_standard_fixtures,
    test_battery_planner_context_variants,
    test_battery_spillover_standard_plans,
    test_battery_replan_standard_scenarios,
    test_battery_big_model_standard_splits,
    test_battery_fairness_standard_scripts,
)
from tests.test_phase_timing import (
    test_phase_timing_coverage_arithmetic,
    test_phase_timing_disjoint_pure,
    test_phase_timing_json_schema,
    test_phase_timing_kvcache_sink,
)
from tests.test_parity_battery_a045 import (
    test_parity_top_token_ties,
    test_parity_rank_arithmetic,
    test_parity_gap_arithmetic,
    test_parity_verdict_bands,
    test_parity_logit_sink_defaults,
)
from tests.test_teacher_forcing_harness_a109 import (
    test_tf_raw_prompt_accepted,
    test_tf_template_rejected,
    test_tf_backend_and_oracle_gate,
    test_tf_grade_all_backends_one_harness,
    test_tf_grade_near_tie_and_divergence,
    test_tf_a045_reproduction,
    test_tf_summary_digest_reproducible,
)
from tests.test_sampling_cost_a044 import (
    test_sampling_cost_simd_max_parity,
    test_sampling_cost_greedy_argmax_parity,
    test_sampling_cost_sort_stable_reference,
    test_sampling_cost_topk_reference,
    test_sampling_cost_stochastic_determinism_large,
)
from tests.test_precision_paths import (
    test_precision_f32_accumulation_dyadic_exact,
    test_precision_f16_gemm_f64_reference,
    test_precision_bf16_gemm_f64_reference,
    test_precision_bf16_widening_exact,
    test_precision_f16_roundtrip_bound,
    test_precision_rmsnorm_f32_f64_reference,
)
from tests.test_conversation import (
    test_conversation_codec,
    test_conversation_compatibility,
)
from tests.test_prompt_prefix import test_prompt_prefix
from tests.test_dense_buffers import test_dense_buffers
from tests.test_turing_fixture_plan import test_turing_fixture_plan
from tests.test_turing_fixture_control import test_turing_fixture_control
from tests.test_turing_replay_plan import test_turing_replay_plan
from tests.test_chat_recovery import (
    test_chat_recovery_policy,
    test_chat_recovery_snapshot_validation,
)
from tests.test_conversation_autosave import (
    test_conversation_autosave_generations,
    test_conversation_autosave_corrupt_records,
)
from tests.test_model_preferences import (
    test_model_preferences_codec,
    test_model_favorite_selection,
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
    test_error_guard_finiteness,
    test_state_vault,
    test_state_vault_read_exact_bytes,
    test_state_vault_rejects_growth,
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
    test_hf_resume_completion_verification,
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
from tests.test_mmproj import test_mmproj
from tests.test_image_prep import test_image_prep
from tests.test_vision_encoder import test_vision_encoder
from tests.test_embedding_span import test_embedding_span


def main() raises:
    var ledger = TestLedger()
    run_case(ledger, "hardware.host_memory", test_host_memory_observations)
    run_case(ledger, "hardware.inference_memory_counts", test_native_memory_counts)
    run_case(ledger, "hardware.inference_memory_rejection", test_native_memory_rejection)
    run_case(ledger, "hardware.native_device_selection", test_native_device_selection)
    run_case(ledger, "hardware.automatic_context_sequence", test_automatic_context_sequence)
    run_case(ledger, "hardware.planning_cli_rejection", test_native_planning_cli_rejection)
    run_case(ledger, "storage.persisted_text_admission", test_persisted_text_admission)

    print("==============================================")
    print("  ⚡ Project Aesir — The Grand Proving ⚡")
    print("==============================================")
    print("")

    # --- Compute Kernels ---
    print("  [DOMAIN] Core Compute Kernels")
    print("  -----------------------------------------")
    run_case(ledger, "compute.gemm_f16", test_gemm)
    run_case(
        ledger,
        "compute.gemm_f16_gpgpu_vector_fallback",
        test_gemm_f16_gpgpu_vector_cpu_fallback,
    )
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
    run_case(ledger, "gguf.version_interface", test_gguf_version_interface)
    run_case(ledger, "gguf.version_reference", test_gguf_version_reference)
    run_case(ledger, "gguf.version_integration", test_gguf_version_integration)
    run_case(ledger, "gguf.header_adversarial", test_gguf_header_adversarial)
    run_case(ledger, "gguf.metadata_type_baseline", test_gguf_metadata_type_rejection)
    run_case(ledger, "gguf.metadata_type_integration", test_gguf_metadata_type_integration)
    run_case(ledger, "gguf.tensor_directory_baseline", test_gguf_tensor_directory_baseline)
    run_case(ledger, "gguf.tensor_directory_interface", test_gguf_tensor_directory_interface)
    run_case(ledger, "gguf.tensor_directory_adversarial", test_gguf_tensor_directory_adversarial)
    run_case(ledger, "gguf.tensor_directory_integration", test_gguf_tensor_directory_integration)
    run_case(ledger, "gguf.tensor_directory_pool_adversarial", test_gguf_tensor_directory_pool_adversarial)
    print("")

    # --- Vision (mmproj) ---
    print("  [DOMAIN] Vision (mmproj)")
    print("  -----------------------------------------")
    run_case(ledger, "vision.mmproj_structure", test_mmproj)
    run_case(ledger, "vision.image_preprocessing", test_image_prep)
    run_case(ledger, "vision.encoder_stages", test_vision_encoder)
    run_case(ledger, "vision.embedding_span_injection", test_embedding_span)
    record_skip(
        ledger,
        "vision.cuda_session_image_chat",
        "requires the real Gemma 4 pair and a CUDA device; opt-in program tests/image_chat_cuda_mmproj.mojo",
    )
    print("")

    # --- Tokenizer ---
    print("  [DOMAIN] RuneWeaver Tokenizer")
    print("  -----------------------------------------")
    run_case(ledger, "tokenizer.synthetic_bpe", test_tokenizer)
    run_case(ledger, "tokenizer.byte_bpe_merge_baseline", test_byte_bpe_merge_baseline)
    run_case(ledger, "tokenizer.byte_bpe_merge_interface", test_byte_bpe_merge_interface)
    run_case(ledger, "tokenizer.byte_bpe_merge_adversarial", test_byte_bpe_merge_adversarial)
    run_case(ledger, "tokenizer.byte_bpe_merge_integration", test_byte_bpe_merge_integration)
    run_case(ledger, "tokenizer.byte_bpe_merge_negative_scores", test_byte_bpe_merge_negative_scores)
    run_case(ledger, "tokenizer.unicode_normalization_baseline", test_unicode_normalization_baseline)
    run_case(ledger, "tokenizer.unicode_normalization_interface", test_unicode_normalization_interface)
    run_case(ledger, "tokenizer.unicode_normalization_integration", test_unicode_normalization_integration)
    run_case(ledger, "tokenizer.unicode_normalization_adversarial", test_unicode_normalization_adversarial)
    run_case(ledger, "tokenizer.invalid_utf8_baseline", test_invalid_utf8_rejection)
    run_case(ledger, "tokenizer.invalid_utf8_adversarial", test_invalid_utf8_adversarial)
    run_case(ledger, "tokenizer.invalid_utf8_integration", test_invalid_utf8_integration)
    run_case(ledger, "tokenizer.invalid_utf8_single_byte_sweep", test_invalid_utf8_single_byte_sweep)
    run_case(ledger, "tokenizer.edge_empty_and_bos", test_tokenizer_edge_empty_and_bos)
    run_case(ledger, "tokenizer.edge_no_vocab_fallback", test_tokenizer_edge_no_vocab_fallback)
    run_case(ledger, "tokenizer.edge_unicode_emoji", test_tokenizer_edge_unicode_emoji)
    run_case(ledger, "tokenizer.edge_control_tokens", test_tokenizer_edge_control_tokens)
    run_case(ledger, "tokenizer.edge_invalid_utf8", test_tokenizer_edge_invalid_utf8)
    run_case(ledger, "tokenizer.edge_oversized", test_tokenizer_edge_oversized)
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
    run_case(ledger, "inference.iq_embedding_lookup", test_iq_embedding_lookup)
    run_case(ledger, "inference.synthetic_forward", test_forward_pass)
    run_case(ledger, "sampling.greedy_tie_policy", test_greedy_tie_policy)
    run_case(ledger, "sampling.greedy_tie_adversarial", test_greedy_tie_adversarial)
    run_case(ledger, "sampling.temperature_distribution_oracle", test_temperature_distribution_oracle)
    run_case(ledger, "sampling.temperature_integration", test_temperature_sampling_integration)
    run_case(ledger, "sampling.temperature_adversarial", test_temperature_sampling_adversarial)
    run_case(ledger, "sampling.top_k_boundaries", test_top_k_boundary_semantics)
    run_case(ledger, "sampling.top_k_integration", test_top_k_sampling_integration)
    run_case(ledger, "sampling.top_k_adversarial", test_top_k_adversarial)
    run_case(
        ledger,
        "inference.rmsnorm_integration",
        test_rmsnorm_inference_integration,
    )
    run_case(ledger, "inference.stop_policy", test_generation_stop_policy)
    run_case(
        ledger,
        "inference.unsupported_runtime_config",
        test_unsupported_runtime_config,
    )
    run_case(ledger, "inference.prompt_byte_bound", test_prompt_byte_bound)
    run_case(ledger, "inference.kv_cache", test_kv_cache)
    run_case(
        ledger, "memory.allocation_bounds", test_mimir_well_allocation_bounds
    )
    run_case(ledger, "memory.checked_span", test_checked_span)
    run_case(ledger, "io.stream_reader", test_stream_reader)
    run_case(ledger, "memory.expert_cache", test_expert_cache)
    run_case(ledger, "memory.dense_residency", test_dense_residency)
    run_case(ledger, "memory.rune_tensor_layout", test_rune_tensor_layout)
    run_case(ledger, "compute.rmsnorm_interface", test_rmsnorm_interface)
    run_case(ledger, "compute.rmsnorm_reference", test_rmsnorm_reference)
    run_case(ledger, "compute.rmsnorm_adversarial", test_rmsnorm_adversarial)
    run_case(ledger, "compute.rope_interface", test_rope_interface)
    run_case(ledger, "compute.rope_reference", test_rope_reference)
    run_case(ledger, "compute.rope_integration", test_rope_integration)
    run_case(ledger, "compute.attention_interface", test_attention_interface)
    run_case(ledger, "compute.attention_reference", test_attention_reference)
    run_case(ledger, "compute.attention_integration", test_attention_integration)
    run_case(ledger, "compute.attention_adversarial", test_attention_adversarial)
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
    run_case(ledger, "npu.probe_absence", test_npu_probe_absence)
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
        ledger, "gpu.probe_failure_notes", test_topology_probe_failure_notes
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
        "gpu.allocation_tracker_adversarial",
        test_cuda_allocation_tracker_adversarial,
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
    run_case(ledger, "gpu.amd_hip_device_gate", test_amd_hip_device_gate)
    run_case(
        ledger, "gpu.amd_hip_properties_parser", test_amd_hip_properties_parser
    )
    run_case(
        ledger, "gpu.amd_hip_malloc_free_round_trip", test_hip_malloc_free_round_trip
    )
    run_case(ledger, "gpu.amd_hip_alloc_rejection", test_hip_alloc_rejection)
    run_case(
        ledger,
        "gpu.amd_hip_malloc_managed_round_trip",
        test_hip_malloc_managed_round_trip,
    )
    run_case(
        ledger,
        "gpu.amd_hip_mem_get_info_accounting",
        test_hip_mem_get_info_accounting,
    )
    run_case(ledger, "gpu.amd_hip_no_leak_1000", test_hip_no_leak_1000)
    run_case(
        ledger, "gpu.amd_hip_sync_oracle_round_trip", test_hip_sync_oracle_round_trip
    )
    run_case(
        ledger, "gpu.amd_hip_stream_async_round_trip", test_hip_stream_async_round_trip
    )
    run_case(
        ledger, "gpu.amd_hip_stream_overlap_smoke", test_hip_stream_overlap_smoke
    )
    run_case(ledger, "gpu.amd_hip_event_timing", test_hip_event_timing)
    run_case(ledger, "gpu.amd_hip_stream_rejection", test_hip_stream_rejection)
    run_case(ledger, "gpu.vulkan_context_create", test_vulkan_context_create)
    run_case(
        ledger, "gpu.vulkan_taxonomy_mapping", test_vulkan_taxonomy_mapping
    )
    run_case(
        ledger,
        "gpu.vulkan_forced_failure_taxonomy",
        test_vulkan_forced_failure_taxonomy,
    )
    run_case(
        ledger, "gpu.vulkan_context_rejection", test_vulkan_context_rejection
    )
    run_case(
        ledger,
        "gpu.vulkan_buffer_alignment_rules",
        test_vulkan_buffer_alignment_rules,
    )
    run_case(
        ledger, "gpu.vulkan_buffer_round_trip", test_vulkan_buffer_round_trip
    )
    run_case(
        ledger,
        "gpu.vulkan_buffer_alloc_rejection",
        test_vulkan_buffer_alloc_rejection,
    )
    run_case(ledger, "gpu.vulkan_buffer_no_leak", test_vulkan_buffer_no_leak)
    run_case(
        ledger,
        "gguf.weight_residency_accounting_rules",
        test_weight_residency_accounting_rules,
    )
    run_case(
        ledger,
        "gguf.weight_residency_mapping_accounting",
        test_weight_residency_mapping_accounting,
    )
    run_case(
        ledger,
        "gguf.weight_residency_gpu_visibility",
        test_weight_residency_gpu_visibility,
    )
    run_case(
        ledger,
        "gguf.weight_residency_no_device_copy",
        test_weight_residency_no_device_copy,
    )
    run_case(ledger, "gpu.vulkan_dispatch_vec_add_oracle", test_vulkan_dispatch_vec_add_oracle)
    run_case(ledger, "gpu.vulkan_dispatch_rejection", test_vulkan_dispatch_rejection)
    run_case(ledger, "gpu.vulkan_dispatch_no_leak", test_vulkan_dispatch_no_leak)
    run_case(ledger, "gpu.spirv_pipeline_manifest", test_spirv_pipeline_manifest)
    run_case(ledger, "gpu.spirv_pipeline_hashes_recorded", test_spirv_pipeline_hashes_recorded)
    run_case(ledger, "gpu.spirv_pipeline_header_embedded", test_spirv_pipeline_header_embedded)
    run_case(ledger, "gpu.spirv_pipeline_no_runtime_fetch", test_spirv_pipeline_no_runtime_fetch)
    run_case(ledger, "gpu.spirv_pipeline_toolchain_recorded", test_spirv_pipeline_toolchain_recorded)
    run_case(ledger, "gpu.vulkan_q8_gemv_oracle_parity", test_vulkan_q8_gemv_oracle_parity)
    run_case(ledger, "gpu.vulkan_q8_gemv_known_value", test_vulkan_q8_gemv_known_value)
    run_case(ledger, "gpu.vulkan_q8_gemv_engine_crosscheck", test_vulkan_q8_gemv_engine_crosscheck)
    run_case(ledger, "gpu.vulkan_q8_gemv_rejection", test_vulkan_q8_gemv_rejection)
    run_case(ledger, "gpu.vulkan_q8_gemv_dispatch_evidence", test_vulkan_q8_gemv_dispatch_evidence)
    run_case(ledger, "gpu.vulkan_attn_decode_oracle_parity", test_vulkan_attn_decode_oracle_parity)
    run_case(ledger, "gpu.vulkan_attn_decode_known_value", test_vulkan_attn_decode_known_value)
    run_case(ledger, "gpu.vulkan_attn_decode_gqa_fixture", test_vulkan_attn_decode_gqa_fixture)
    run_case(ledger, "gpu.vulkan_attn_decode_rejection", test_vulkan_attn_decode_rejection)
    run_case(ledger, "gpu.vulkan_attn_decode_dispatch_evidence", test_vulkan_attn_decode_dispatch_evidence)
    run_case(ledger, "gpu.vulkan_sampling_greedy_oracle_parity", test_vulkan_sampling_greedy_oracle_parity)
    run_case(ledger, "gpu.vulkan_sampling_greedy_tie_policy", test_vulkan_sampling_greedy_tie_policy)
    run_case(ledger, "gpu.vulkan_sampling_sample_oracle_exact", test_vulkan_sampling_sample_oracle_exact)
    run_case(ledger, "gpu.vulkan_sampling_temperature_distribution", test_vulkan_sampling_temperature_distribution)
    run_case(ledger, "gpu.vulkan_sampling_rejection", test_vulkan_sampling_rejection)
    run_case(ledger, "gpu.vulkan_sampling_dispatch_evidence", test_vulkan_sampling_dispatch_evidence)
    run_case(ledger, "gpu.gpu_weight_residency_single", test_gpu_weight_residency_single)
    run_case(ledger, "gpu.gpu_weight_residency_no_reupload", test_gpu_weight_residency_no_reupload)
    run_case(ledger, "gpu.gpu_weight_residency_cpu_shared", test_gpu_weight_residency_cpu_shared)
    run_case(ledger, "gpu.gpu_weight_residency_multi_tensor", test_gpu_weight_residency_multi_tensor)
    run_case(ledger, "gpu.gpu_weight_residency_rejection", test_gpu_weight_residency_rejection)
    run_case(ledger, "gpu.vulkan_layer_oracle_parity", test_vulkan_layer_oracle_parity)
    run_case(ledger, "gpu.vulkan_layer_known_value", test_vulkan_layer_known_value)
    run_case(ledger, "gpu.vulkan_layer_standalone_index", test_vulkan_layer_standalone_index)
    run_case(ledger, "gpu.vulkan_layer_rejection", test_vulkan_layer_rejection)
    run_case(ledger, "gpu.vulkan_layer_dispatch_evidence", test_vulkan_layer_dispatch_evidence)
    run_case(ledger, "gpu.vulkan_decode_kv_append_parity", test_vulkan_decode_kv_append_parity)
    run_case(ledger, "gpu.vulkan_decode_strided_attention_parity", test_vulkan_decode_strided_attention_parity)
    run_case(ledger, "gpu.vulkan_decode_token_exact", test_vulkan_decode_token_exact)
    run_case(ledger, "gpu.vulkan_decode_rejection", test_vulkan_decode_rejection)
    run_case(ledger, "gpu.vulkan_real_model_sanitize_policy", test_vulkan_real_model_sanitize_policy)
    run_case(ledger, "gpu.vulkan_real_model_rope_permutation", test_vulkan_real_model_rope_permutation)
    run_case(ledger, "gpu.vulkan_real_model_fixture_config", test_vulkan_real_model_fixture_config)
    run_case(ledger, "gpu.vulkan_real_model_teacher_forcing", test_vulkan_real_model_teacher_forcing)
    run_case(ledger, "gpu.vulkan_real_model_generation", test_vulkan_real_model_generation)
    run_case(ledger, "gpu.vulkan_real_model_dispatch_evidence", test_vulkan_real_model_dispatch_evidence)
    run_case(ledger, "gpu.vulkan_real_model_rejection", test_vulkan_real_model_rejection)
    run_case(ledger, "gpu.vulkan_chunked_prefill_cpu_oracle_parity", test_vulkan_chunked_prefill_cpu_oracle_parity)
    run_case(ledger, "gpu.vulkan_chunked_prefill_identical_to_unchunked", test_vulkan_chunked_prefill_identical_to_unchunked)
    run_case(ledger, "gpu.vulkan_chunked_prefill_causal_isolation", test_vulkan_chunked_prefill_causal_isolation)
    run_case(ledger, "gpu.vulkan_chunked_prefill_rope_global_positions", test_vulkan_chunked_prefill_rope_global_positions)
    run_case(ledger, "gpu.vulkan_chunked_prefill_kv_append_chunk_slots", test_vulkan_chunked_prefill_kv_append_chunk_slots)
    run_case(ledger, "gpu.vulkan_chunked_prefill_rejection", test_vulkan_chunked_prefill_rejection)
    run_case(ledger, "gpu.vulkan_chunked_prefill_dispatch_and_bounds", test_vulkan_chunked_prefill_dispatch_and_bounds)
    run_case(ledger, "gpu.vulkan_continuous_batch_four_match_single", test_vulkan_continuous_batch_four_match_single)
    run_case(ledger, "gpu.vulkan_continuous_batch_heterogeneous", test_vulkan_continuous_batch_heterogeneous)
    run_case(ledger, "gpu.vulkan_continuous_batch_dynamic_admission", test_vulkan_continuous_batch_dynamic_admission)
    run_case(ledger, "gpu.vulkan_continuous_batch_isolation", test_vulkan_continuous_batch_isolation)
    run_case(ledger, "gpu.vulkan_continuous_batch_rejection", test_vulkan_continuous_batch_rejection)
    run_case(ledger, "gpu.vulkan_continuous_batch_single_slot_serial", test_vulkan_continuous_batch_single_slot_serial)
    run_case(ledger, "accum_policy.table_completeness", test_accum_policy_table_completeness)
    run_case(ledger, "accum_policy.table_uniform_fp32", test_accum_policy_table_uniform_fp32)
    run_case(ledger, "accum_policy.dot_error_k_scaling", test_accum_policy_dot_error_k_scaling)
    run_case(ledger, "accum_policy.logit_gap_battery", test_accum_policy_logit_gap_battery)
    run_case(ledger, "accum_policy.norm_mass_attention", test_accum_policy_norm_mass_attention)
    run_case(ledger, "accum_policy.emulation_invariants", test_accum_policy_emulation_invariants)
    run_case(ledger, "gpu.vulkan_prefill_gemm_oracle_parity", test_vulkan_prefill_gemm_oracle_parity)
    run_case(ledger, "gpu.vulkan_prefill_gemm_known_value", test_vulkan_prefill_gemm_known_value)
    run_case(ledger, "gpu.vulkan_prefill_gemm_f32_parity", test_vulkan_prefill_gemm_f32_parity)
    run_case(ledger, "gpu.vulkan_prefill_gemm_batch_independence", test_vulkan_prefill_gemm_batch_independence)
    run_case(ledger, "cpu_assist.stats_accounting", test_cpu_assist_stats_accounting)
    run_case(ledger, "cpu_assist.policy_verdicts", test_cpu_assist_policy_verdicts)
    run_case(ledger, "cpu_assist.stitch_equivalence", test_cpu_assist_stitch_equivalence)
    run_case(ledger, "cpu_assist.sanitize_policy", test_cpu_assist_sanitize_policy)
    run_case(ledger, "cpu_assist.inventory_completeness", test_cpu_assist_inventory_completeness)
    run_case(ledger, "cpu_assist.stats_absent_model", test_cpu_assist_stats_absent_model)
    run_case(ledger, "gpu.vulkan_prefill_gemm_rejection", test_vulkan_prefill_gemm_rejection)
    run_case(ledger, "gpu.vulkan_prefill_gemm_dispatch_evidence", test_vulkan_prefill_gemm_dispatch_evidence)
    run_case(ledger, "gpu.vulkan_async_token_identity", test_vulkan_async_token_identity)
    run_case(ledger, "gpu.vulkan_async_no_wait_idle", test_vulkan_async_no_wait_idle)
    run_case(ledger, "gpu.vulkan_async_timeline_sane", test_vulkan_async_timeline_sane)
    run_case(ledger, "gpu.vulkan_async_dispatch_queueing", test_vulkan_async_dispatch_queueing)
    run_case(ledger, "gpu.vulkan_async_rejection", test_vulkan_async_rejection)
    run_case(ledger, "gpu.vulkan_async_dispatch_evidence", test_vulkan_async_dispatch_evidence)
    run_case(ledger, "gpu_fuzz.seed_replay", test_gpu_fuzz_seed_replay)
    run_case(ledger, "gpu_fuzz.case_coverage", test_gpu_fuzz_case_coverage)
    run_case(ledger, "gpu_fuzz.verdict_classifier", test_gpu_fuzz_verdict_classifier)
    run_case(ledger, "gpu_fuzz.synthetic_row_battery", test_gpu_fuzz_synthetic_row_battery)
    run_case(ledger, "gpu_fuzz.sampling_greedy", test_gpu_fuzz_sampling_greedy)
    run_case(ledger, "gpu_fuzz.sampling_temperature", test_gpu_fuzz_sampling_temperature)
    run_case(ledger, "gpu_fuzz.real_model_random_prompts", test_gpu_fuzz_real_model_random_prompts)
    run_case(ledger, "equivalence.classifier_table", test_equivalence_classifier_table)
    run_case(ledger, "equivalence.battery_aggregation", test_equivalence_battery_aggregation)
    run_case(ledger, "equivalence.regression_blocks", test_equivalence_regression_blocks)
    run_case(ledger, "equivalence.gate_script_contract", test_equivalence_gate_script_contract)
    run_case(ledger, "equivalence.sampling_parity", test_equivalence_sampling_parity)
    run_case(ledger, "equivalence.real_model_parity", test_equivalence_real_model_parity)
    run_case(ledger, "gpu.gpu_pressure_classification", test_gpu_pressure_classification)
    run_case(ledger, "gpu.gpu_pressure_gpu_route_baseline", test_gpu_pressure_gpu_route_baseline)
    run_case(ledger, "gpu.gpu_pressure_squeeze_spill_refuse", test_gpu_pressure_squeeze_spill_refuse)
    run_case(ledger, "gpu.gpu_pressure_bounded_degradation", test_gpu_pressure_bounded_degradation)
    run_case(ledger, "gpu.gpu_pressure_recovery", test_gpu_pressure_recovery)
    run_case(ledger, "gpu.gpu_pressure_live_and_log_bound", test_gpu_pressure_live_and_log_bound)
    run_case(ledger, "gpu.gpu_pressure_device_buffer", test_gpu_pressure_device_buffer)
    run_case(ledger, "sched.spillover_all_fit_gpu", test_spillover_all_fit_gpu)
    run_case(ledger, "sched.spillover_capacity_spill_order", test_spillover_capacity_spill_order)
    run_case(ledger, "sched.spillover_nonspillable_refusal_atomic", test_spillover_nonspillable_refusal_atomic)
    run_case(ledger, "sched.spillover_spill_cap_bound", test_spillover_spill_cap_bound)
    run_case(ledger, "sched.spillover_assist_evidence_gate", test_spillover_assist_evidence_gate)
    run_case(ledger, "sched.spillover_log_reproducible", test_spillover_log_reproducible)
    run_case(ledger, "sched.spillover_device_execution", test_spillover_device_execution)
    run_case(ledger, "sched.fairness_equal_share", test_fairness_equal_share)
    run_case(ledger, "sched.fairness_weighted_share", test_fairness_weighted_share)
    run_case(ledger, "sched.fairness_no_starvation_adversarial", test_fairness_no_starvation_adversarial)
    run_case(ledger, "sched.fairness_idle_no_hoard", test_fairness_idle_no_hoard)
    run_case(ledger, "sched.fairness_single_model_throughput", test_fairness_single_model_throughput)
    run_case(ledger, "sched.fairness_governor_pressure", test_fairness_governor_pressure)
    run_case(ledger, "sched.fairness_log_reproducible", test_fairness_log_reproducible)
    run_case(ledger, "sched.fairness_device_execution", test_fairness_device_execution)
    run_case(ledger, "sched.telemetry_live_bounds", test_telemetry_live_bounds)
    run_case(ledger, "sched.telemetry_cpu_util_parser", test_telemetry_cpu_util_parser)
    run_case(ledger, "sched.telemetry_external_match", test_telemetry_external_match)
    run_case(ledger, "sched.telemetry_placement_decisions_exposed", test_telemetry_placement_decisions_exposed)
    run_case(ledger, "sched.telemetry_clamp_and_tolerance", test_telemetry_clamp_and_tolerance)
    run_case(ledger, "sched.telemetry_no_device_graceful", test_telemetry_no_device_graceful)
    run_case(ledger, "sched.telemetry_gpu_memory_reacts", test_telemetry_gpu_memory_reacts)
    run_case(ledger, "sched.telemetry_cpu_util_live_window", test_telemetry_cpu_util_live_window)
    run_case(ledger, "gpu.gpu_soak_slope_flat_and_leak", test_gpu_soak_slope_flat_and_leak)
    run_case(ledger, "gpu.gpu_soak_verdict_precedence", test_gpu_soak_verdict_precedence)
    run_case(ledger, "gpu.gpu_soak_tally_accounting", test_gpu_soak_tally_accounting)
    run_case(ledger, "gpu.gpu_soak_live_rss_reader", test_gpu_soak_live_rss_reader)
    run_case(ledger, "gpu.gpu_soak_device_burst", test_gpu_soak_device_burst)
    run_case(ledger, "gpu.device_lost_taxonomy", test_device_lost_taxonomy)
    run_case(ledger, "gpu.device_lost_control_parity", test_device_lost_control_parity)
    run_case(ledger, "gpu.device_lost_failover_midrun", test_device_lost_failover_midrun)
    run_case(ledger, "gpu.device_lost_fail_closed_state_intact", test_device_lost_fail_closed_state_intact)
    run_case(ledger, "gpu.device_lost_edges_and_repeat", test_device_lost_edges_and_repeat)
    run_case(ledger, "gpu.device_lost_watchdog_bound", test_device_lost_watchdog_bound)
    run_case(ledger, "gpu.device_lost_live_shim_fail_closed", test_device_lost_live_shim_fail_closed)
    run_case(ledger, "gpu.vulkan_q6k_q5k_oracle_parity", test_vulkan_q6k_q5k_oracle_parity)
    run_case(ledger, "gpu.vulkan_q6k_q5k_known_value", test_vulkan_q6k_q5k_known_value)
    run_case(ledger, "gpu.vulkan_q6k_q5k_engine_crosscheck", test_vulkan_q6k_q5k_engine_crosscheck)
    run_case(ledger, "gpu.vulkan_q6k_q5k_rejection", test_vulkan_q6k_q5k_rejection)
    run_case(ledger, "gpu.vulkan_q6k_q5k_dispatch_evidence", test_vulkan_q6k_q5k_dispatch_evidence)
    run_case(ledger, "gpu.vulkan_iq_gemv_oracle_parity", test_vulkan_iq_gemv_oracle_parity)
    run_case(ledger, "gpu.vulkan_iq_gemv_known_value", test_vulkan_iq_gemv_known_value)
    run_case(ledger, "gpu.vulkan_iq_gemv_engine_crosscheck", test_vulkan_iq_gemv_engine_crosscheck)
    run_case(ledger, "gpu.vulkan_iq_gemv_rejection", test_vulkan_iq_gemv_rejection)
    run_case(ledger, "gpu.vulkan_iq_gemv_dispatch_evidence", test_vulkan_iq_gemv_dispatch_evidence)
    run_case(ledger, "gpu.vulkan_elementwise_oracle_parity", test_vulkan_elementwise_oracle_parity)
    run_case(ledger, "gpu.vulkan_elementwise_known_value", test_vulkan_elementwise_known_value)
    run_case(ledger, "gpu.vulkan_softmax_oracle_parity", test_vulkan_softmax_oracle_parity)
    run_case(ledger, "gpu.vulkan_softmax_adversarial", test_vulkan_softmax_adversarial)
    run_case(ledger, "gpu.vulkan_elementwise_softmax_rejection", test_vulkan_elementwise_softmax_rejection)
    run_case(ledger, "gpu.vulkan_elementwise_softmax_dispatch_evidence", test_vulkan_elementwise_softmax_dispatch_evidence)
    run_case(ledger, "gpu.vulkan_q4k_gemv_oracle", test_vulkan_q4k_gemv_oracle)
    run_case(ledger, "gpu.vulkan_q4k_gemv_rejection", test_vulkan_q4k_gemv_rejection)
    run_case(ledger, "gpu.vulkan_q4k_gemv_no_leak", test_vulkan_q4k_gemv_no_leak)
    run_case(ledger, "gpu.vulkan_rmsnorm_oracle_parity", test_vulkan_rmsnorm_oracle_parity)
    run_case(ledger, "gpu.vulkan_rmsnorm_known_value", test_vulkan_rmsnorm_known_value)
    run_case(ledger, "gpu.vulkan_rope_oracle_parity", test_vulkan_rope_oracle_parity)
    run_case(ledger, "gpu.vulkan_rope_known_properties", test_vulkan_rope_known_properties)
    run_case(ledger, "gpu.vulkan_rmsnorm_rope_rejection", test_vulkan_rmsnorm_rope_rejection)
    run_case(ledger, "gpu.vulkan_rmsnorm_rope_dispatch_evidence", test_vulkan_rmsnorm_rope_dispatch_evidence)
    run_case(ledger, "gpu.zero_copy_hip_cpu_write_gpu_read", test_zero_copy_hip_cpu_write_gpu_read)
    run_case(ledger, "gpu.zero_copy_hip_gpu_write_cpu_read", test_zero_copy_hip_gpu_write_cpu_read)
    run_case(ledger, "gpu.zero_copy_vulkan_cpu_write_gpu_read", test_zero_copy_vulkan_cpu_write_gpu_read)
    run_case(ledger, "gpu.zero_copy_rejection", test_zero_copy_rejection)
    run_case(ledger, "gpu.zero_copy_no_leak", test_zero_copy_no_leak)
    run_case(ledger, "gpu.arena_reset_semantics", test_arena_reset_semantics)
    run_case(ledger, "gpu.arena_rejection", test_arena_rejection)
    run_case(ledger, "gpu.arena_fragmentation_stress", test_arena_fragmentation_stress)
    run_case(ledger, "gpu.arena_pool_device", test_arena_pool_device)
    run_case(ledger, "gpu.arena_shim_registry_over_4096", test_arena_shim_registry_over_4096)
    run_case(ledger, "memory.budget_cap_honoured_measured", test_budget_cap_honoured_measured)
    run_case(ledger, "memory.budget_refusal_fail_closed", test_budget_refusal_fail_closed)
    run_case(ledger, "memory.budget_spill_degradation", test_budget_spill_degradation)
    run_case(ledger, "memory.budget_configurability", test_budget_configurability)
    run_case(ledger, "memory.budget_accounting_baseline", test_budget_accounting_baseline)
    run_case(ledger, "memory.budget_live_meminfo_pressure", test_budget_live_meminfo_pressure)
    run_case(ledger, "gpu.mojo_native_vec_add_oracle", test_mojo_native_vec_add_oracle)
    run_case(ledger, "gpu.mojo_native_gemm_oracle", test_mojo_native_gemm_oracle)
    run_case(ledger, "gpu.mojo_native_rejection", test_mojo_native_rejection)
    run_case(ledger, "gpu.hip_q8_gemv_oracle_parity", test_hip_q8_gemv_oracle_parity)
    run_case(ledger, "gpu.hip_q8_gemv_known_value", test_hip_q8_gemv_known_value)
    run_case(ledger, "gpu.hip_q8_gemv_engine_crosscheck", test_hip_q8_gemv_engine_crosscheck)
    run_case(ledger, "gpu.hip_q8_gemv_rejection", test_hip_q8_gemv_rejection)
    run_case(ledger, "gpu.hip_q8_gemv_dispatch_evidence", test_hip_q8_gemv_dispatch_evidence)
    run_case(ledger, "gpu.hip_q4k_gemv_oracle", test_hip_q4k_gemv_oracle)
    run_case(ledger, "gpu.hip_q4k_gemv_rejection", test_hip_q4k_gemv_rejection)
    run_case(ledger, "gpu.hip_q4k_gemv_no_leak", test_hip_q4k_gemv_no_leak)
    run_case(ledger, "gpu.hip_attn_norms_rmsnorm_oracle", test_hip_attn_norms_rmsnorm_oracle)
    run_case(ledger, "gpu.hip_attn_norms_rope_oracle", test_hip_attn_norms_rope_oracle)
    run_case(ledger, "gpu.hip_attn_norms_attention_oracle", test_hip_attn_norms_attention_oracle)
    run_case(ledger, "gpu.hip_attn_norms_rejection", test_hip_attn_norms_rejection)
    run_case(ledger, "gpu.hip_attn_norms_dispatch_evidence", test_hip_attn_norms_dispatch_evidence)
    run_case(ledger, "rocm_repro.pin_table_exact", test_rocm_repro_pin_table)
    run_case(ledger, "rocm_repro.convergence_accepts", test_rocm_repro_convergence_accepts)
    run_case(ledger, "rocm_repro.convergence_rejects_drift", test_rocm_repro_convergence_rejects)
    run_case(ledger, "rocm_repro.script_contract", test_rocm_repro_script_contract)
    run_case(ledger, "rocm_repro.script_core_sync", test_rocm_repro_script_sync)
    run_case(ledger, "gpu.kv_unified_layout", test_kv_unified_layout)
    run_case(ledger, "gpu.kv_unified_bounds", test_kv_unified_bounds)
    run_case(ledger, "gpu.kv_unified_gpu_write_cpu_read", test_kv_unified_gpu_write_cpu_read)
    run_case(ledger, "gpu.kv_unified_cpu_write_gpu_read", test_kv_unified_cpu_write_gpu_read)
    run_case(ledger, "gpu.kv_unified_append_roundtrip", test_kv_unified_append_roundtrip)
    run_case(ledger, "gpu.kv_unified_vulkan_shared", test_kv_unified_vulkan_shared)
    run_case(ledger, "gpu.buffer_ownership_hip_adversarial", test_hip_buffer_ownership_adversarial)
    run_case(ledger, "gpu.buffer_ownership_vulkan_adversarial", test_vulkan_buffer_ownership_adversarial)
    run_case(ledger, "gpu.buffer_ownership_zero_copy_adversarial", test_zero_copy_buffer_ownership_adversarial)
    run_case(ledger, "gpu.buffer_ownership_xrt_contract", test_xrt_bo_ownership_contract)
    run_case(ledger, "cpu.thread_placement_list_parse", test_thread_placement_list_parse)
    run_case(ledger, "cpu.thread_placement_topology_build", test_thread_placement_topology_build)
    run_case(ledger, "cpu.thread_placement_map_spread", test_thread_placement_map_spread)
    run_case(ledger, "cpu.thread_placement_map_pack_ccd", test_thread_placement_map_pack_ccd)
    run_case(ledger, "cpu.thread_placement_reject", test_thread_placement_reject)
    run_case(ledger, "cpu.thread_placement_live_affinity", test_thread_placement_live_affinity)
    run_case(ledger, "cpu.thread_scaling_default_policy", test_thread_scaling_default_policy)
    run_case(ledger, "cpu.thread_scaling_cache_probes", test_thread_scaling_cache_probes)
    run_case(ledger, "cpu.thread_scaling_knob_readback", test_thread_scaling_knob_readback)
    run_case(ledger, "cpu.thread_scaling_stale_until_refresh", test_thread_scaling_stale_until_refresh)
    run_case(ledger, "cpu.thread_scaling_min_work_cached", test_thread_scaling_min_work_cached)
    run_case(ledger, "cpu.thread_scaling_dispatch_identity", test_thread_scaling_dispatch_identity)
    run_case(ledger, "errors.structured_mapping_table", test_structured_errors_mapping_table)
    run_case(ledger, "errors.structured_fault_injection", test_structured_errors_fault_injection)
    run_case(ledger, "errors.structured_real_paths", test_structured_errors_real_paths)
    run_case(ledger, "errors.structured_translation", test_structured_errors_translation)
    run_case(ledger, "errors.structured_vulkan_cpu_consistency", test_structured_errors_vulkan_cpu_consistency)
    run_case(ledger, "errors.hip_mapping_table", test_hip_errors_mapping_table)
    run_case(ledger, "errors.hip_fault_injection", test_hip_errors_fault_injection)
    run_case(ledger, "errors.hip_fallback_and_success", test_hip_errors_fallback_and_success)
    run_case(ledger, "errors.hip_gateway_consistency", test_hip_errors_gateway_consistency)
    run_case(ledger, "errors.hip_real_paths", test_hip_errors_real_paths)
    run_case(ledger, "pipeline.overlap_pairwise_math", test_pipeline_overlap_pairwise_math)
    run_case(ledger, "pipeline.overlap_wall_and_delta", test_pipeline_overlap_wall_and_delta)
    run_case(ledger, "pipeline.overlap_trace_line", test_pipeline_overlap_trace_line)
    run_case(ledger, "pipeline.overlap_acceptance", test_pipeline_overlap_acceptance)
    run_case(ledger, "pipeline.overlap_plan_gating", test_pipeline_overlap_plan_gating)
    run_case(ledger, "pipeline.overlap_filed_trace", test_pipeline_overlap_filed_trace)
    run_case(ledger, "replan.gpu_loss_onto_survivors", test_replan_gpu_loss_onto_survivors)
    run_case(ledger, "replan.npu_loss_uses_survivors", test_replan_npu_loss_uses_survivors)
    run_case(ledger, "replan.drill_gpu_loss_completes_exact", test_replan_drill_gpu_loss_completes_exact)
    run_case(ledger, "replan.drill_npu_loss_completes_exact", test_replan_drill_npu_loss_completes_exact)
    run_case(ledger, "replan.cpu_loss_fails_closed", test_replan_cpu_loss_fails_closed)
    run_case(ledger, "replan.second_failure_fails_closed", test_replan_second_failure_fails_closed)
    run_case(ledger, "replan.edges_and_summary", test_replan_edges_and_summary)
    run_case(ledger, "placement.big_model_geometry", test_big_model_geometry)
    run_case(ledger, "placement.big_model_kv_accounting", test_big_model_kv_accounting)
    run_case(ledger, "placement.big_model_split_half", test_big_model_split_half)
    run_case(ledger, "placement.big_model_split_edges", test_big_model_split_edges)
    run_case(ledger, "placement.big_model_pool_gate", test_big_model_pool_gate)
    run_case(ledger, "placement.big_model_pressure_budget", test_big_model_pressure_budget)
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
        ledger, "cli.catalog_schema_interface", test_catalog_schema_interface
    )
    run_case(
        ledger, "cli.catalog_schema_unit_evidence",
        test_catalog_schema_unit_evidence,
    )
    run_case(
        ledger, "cli.blob_identity_interface", test_blob_identity_interface
    )
    run_case(
        ledger, "cli.blob_identity_unit_evidence",
        test_blob_identity_unit_evidence,
    )
    run_case(
        ledger, "cli.atomic_registration_unit_evidence",
        test_atomic_registration_unit_evidence,
    )
    run_case(
        ledger, "cli.truthful_command_boundaries", test_cli_command_dispatch
    )
    run_case(
        ledger, "cli.repl_session_state", test_repl_session_and_slash_commands
    )
    run_case(ledger, "cli.flag_options_parser", test_cli_flag_options_parser)
    run_case(ledger, "cli.enum_flag_validation", test_cli_enum_flag_validation)
    run_case(ledger, "cli.parse_int_strict", test_parse_int_strict)
    run_case(
        ledger, "cli.duration_strict", test_parse_duration_seconds_strict
    )
    run_case(
        ledger,
        "cli.model_reference_traversal",
        test_model_reference_traversal_fail_closed,
    )
    run_case(ledger, "cli.doctor_observations", test_doctor_observations)
    run_case(ledger, "cli.doctor_readiness", test_doctor_readiness_policy)
    run_case(
        ledger, "cli.doctor_disk_fallback_issue", test_doctor_disk_fallback_issue
    )
    run_case(
        ledger, "cli.doctor_listener_probe_issue", test_doctor_listener_probe_issue
    )
    run_case(ledger, "hardware.census_kfd_parser", test_kfd_gfx_parser)
    run_case(
        ledger, "hardware.census_release_parsers", test_os_release_and_uevent_parsers
    )
    run_case(ledger, "hardware.census_sysfs_numbers", test_sysfs_number_parsers)
    run_case(ledger, "hardware.census_lines", test_census_lines_fixture)
    run_case(ledger, "hardware.census_live", test_live_census_this_machine)
    run_case(ledger, "hardware.census_cuda_absent", test_cuda_absent_is_not_an_error)
    run_case(ledger, "thermal.hwmon_parsers", test_thermal_parsers_and_formats)
    run_case(ledger, "thermal.tolerance_tracking", test_thermal_tolerance_tracking)
    run_case(ledger, "thermal.lines_fixture", test_thermal_lines_fixture)
    run_case(ledger, "thermal.live_sensors", test_thermal_live_this_machine)
    run_case(ledger, "cli.backend_registry_all_present", test_backend_registry_all_present)
    run_case(ledger, "cli.backend_registry_absent_combinations", test_backend_registry_absent_combinations)
    run_case(ledger, "cli.backend_registry_degraded_and_software_vulkan", test_backend_registry_degraded_and_software_vulkan)
    run_case(ledger, "cli.backend_registry_parsers", test_backend_registry_parsers)
    run_case(ledger, "cli.device_policy_accelerator_first", test_device_policy_accelerator_first_all_present)
    run_case(ledger, "cli.device_policy_gpu_backend_fallback", test_device_policy_gpu_backend_fallback)
    run_case(ledger, "cli.device_policy_cpu_spillover_and_none", test_device_policy_cpu_spillover_and_none)
    run_case(ledger, "cli.device_policy_override", test_device_policy_override)
    run_case(ledger, "cli.device_policy_npu_proven_path", test_device_policy_npu_proven_path)
    run_case(ledger, "cli.device_policy_deterministic_log", test_device_policy_deterministic_log)
    run_case(ledger, "cli.backend_config_vocabulary", test_backend_config_vocabulary)
    run_case(ledger, "cli.backend_config_file_and_cli_surface", test_backend_config_file_and_cli_surface)
    run_case(ledger, "cli.backend_config_explicit_resolution", test_backend_config_explicit_resolution)
    run_case(ledger, "cli.backend_config_absent_fail_closed", test_backend_config_absent_fail_closed)
    run_case(ledger, "cli.backend_config_npu_honesty_gate", test_backend_config_npu_honesty_gate)
    run_case(ledger, "cli.backend_config_auto_order", test_backend_config_auto_order)
    run_case(ledger, "gpu_winner.pending_state", test_gpu_winner_pending_state)
    run_case(ledger, "gpu_winner.hip_wins", test_gpu_winner_hip_wins)
    run_case(ledger, "gpu_winner.vulkan_wins", test_gpu_winner_vulkan_wins)
    run_case(ledger, "gpu_winner.invalid_verdicts_fail_closed", test_gpu_winner_invalid_verdicts_fail_closed)
    run_case(ledger, "gpu_winner.probe_only_never_placed", test_gpu_winner_probe_only_never_placed)
    run_case(ledger, "gpu_winner.determinism_and_clear", test_gpu_winner_determinism_and_clear)
    run_case(ledger, "gate.part_iv_verdict_table", test_gate_verdict_table_complete)
    run_case(ledger, "gate.part_iv_no_unexplained", test_gate_no_unexplained_rows)
    run_case(ledger, "gate.part_iv_in_flight_honest", test_gate_in_flight_rows_honest)
    run_case(ledger, "gate.part_iv_negatives", test_gate_negative_verdicts_present)
    run_case(ledger, "gate.part_iv_planner_scope", test_gate_planner_scope_matches_planner)
    run_case(ledger, "gate.part_iv_summary", test_gate_summary_names_scope)
    run_case(ledger, "oracle.pin_registry_judged_rows_pinned", test_pin_registry_judged_rows_pinned)
    run_case(ledger, "oracle.pin_registry_unpinned_unjudged", test_pin_registry_unpinned_example_unjudged)
    run_case(ledger, "oracle.pin_missing_each_blocks", test_pin_missing_each_blocks)
    run_case(ledger, "oracle.pin_malformed_hash_blocks", test_pin_malformed_hash_blocks)
    run_case(ledger, "oracle.pin_mark_judged_success", test_pin_mark_judged_success)
    run_case(ledger, "oracle.pin_build_hash_forms", test_pin_build_hash_forms)
    run_case(ledger, "oracle.pin_registry_file_in_repo", test_pin_registry_file_in_repo)
    run_case(ledger, "gate.near_tie_band_constants", test_near_tie_band_constants)
    run_case(ledger, "gate.near_tie_exact_step", test_near_tie_exact_step)
    run_case(ledger, "gate.near_tie_band_interior", test_near_tie_band_interior)
    run_case(ledger, "gate.near_tie_rank_edge", test_near_tie_rank_edge)
    run_case(ledger, "gate.near_tie_gap_edge", test_near_tie_gap_edge)
    run_case(ledger, "gate.near_tie_invalid_refused", test_near_tie_invalid_records_refused)
    run_case(ledger, "gate.near_tie_comparator_precedence", test_near_tie_comparator_precedence)
    run_case(ledger, "gate.near_tie_row_verdicts", test_near_tie_row_verdicts)
    run_case(ledger, "gate.near_tie_sequence_verdicts", test_near_tie_sequence_verdicts)
    run_case(ledger, "gate.near_tie_matches_prefill", test_near_tie_matches_prefill_grade)
    run_case(ledger, "gate.near_tie_band_line", test_near_tie_band_line)
    run_case(ledger, "planner.standard_fixtures", test_planner_standard_fixtures)
    run_case(ledger, "planner.prefill_variants", test_planner_prefill_variants)
    run_case(ledger, "planner.gemm_thresholds", test_planner_gemm_thresholds)
    run_case(ledger, "planner.decode_and_sampling", test_planner_decode_and_sampling)
    run_case(ledger, "planner.honesty_and_fallback", test_planner_honesty_and_fallback)
    run_case(ledger, "planner.cost_tables_and_lines", test_planner_cost_tables_and_lines)
    run_case(ledger, "battery.planner_standard_fixtures", test_battery_planner_standard_fixtures)
    run_case(ledger, "battery.planner_context_variants", test_battery_planner_context_variants)
    run_case(ledger, "battery.spillover_standard_plans", test_battery_spillover_standard_plans)
    run_case(ledger, "battery.replan_standard_scenarios", test_battery_replan_standard_scenarios)
    run_case(ledger, "battery.big_model_standard_splits", test_battery_big_model_standard_splits)
    run_case(ledger, "battery.fairness_standard_scripts", test_battery_fairness_standard_scripts)
    run_case(ledger, "timing.phase_coverage_arithmetic", test_phase_timing_coverage_arithmetic)
    run_case(ledger, "timing.phase_disjoint_pure", test_phase_timing_disjoint_pure)
    run_case(ledger, "timing.phase_json_schema", test_phase_timing_json_schema)
    run_case(ledger, "timing.phase_kvcache_sink", test_phase_timing_kvcache_sink)
    run_case(ledger, "parity.top_token_ties", test_parity_top_token_ties)
    run_case(ledger, "parity.rank_arithmetic", test_parity_rank_arithmetic)
    run_case(ledger, "parity.gap_arithmetic", test_parity_gap_arithmetic)
    run_case(ledger, "parity.verdict_bands", test_parity_verdict_bands)
    run_case(ledger, "parity.logit_sink_defaults", test_parity_logit_sink_defaults)
    run_case(ledger, "oracle.tf_raw_prompt_accepted", test_tf_raw_prompt_accepted)
    run_case(ledger, "oracle.tf_template_rejected", test_tf_template_rejected)
    run_case(ledger, "oracle.tf_backend_oracle_gate", test_tf_backend_and_oracle_gate)
    run_case(ledger, "oracle.tf_grade_all_backends", test_tf_grade_all_backends_one_harness)
    run_case(ledger, "oracle.tf_grade_bands", test_tf_grade_near_tie_and_divergence)
    run_case(ledger, "oracle.tf_a045_reproduction", test_tf_a045_reproduction)
    run_case(ledger, "oracle.tf_digest_reproducible", test_tf_summary_digest_reproducible)
    run_case(ledger, "sampling_cost.simd_max_parity", test_sampling_cost_simd_max_parity)
    run_case(ledger, "sampling_cost.greedy_argmax_parity", test_sampling_cost_greedy_argmax_parity)
    run_case(ledger, "sampling_cost.sort_stable_reference", test_sampling_cost_sort_stable_reference)
    run_case(ledger, "sampling_cost.topk_reference", test_sampling_cost_topk_reference)
    run_case(ledger, "sampling_cost.stochastic_determinism_large", test_sampling_cost_stochastic_determinism_large)
    run_case(ledger, "precision.f32_accumulation_dyadic_exact", test_precision_f32_accumulation_dyadic_exact)
    run_case(ledger, "precision.f16_gemm_f64_reference", test_precision_f16_gemm_f64_reference)
    run_case(ledger, "precision.bf16_gemm_f64_reference", test_precision_bf16_gemm_f64_reference)
    run_case(ledger, "precision.bf16_widening_exact", test_precision_bf16_widening_exact)
    run_case(ledger, "precision.f16_roundtrip_bound", test_precision_f16_roundtrip_bound)
    run_case(ledger, "precision.rmsnorm_f32_f64_reference", test_precision_rmsnorm_f32_f64_reference)
    run_case(ledger, "cli.conversation_codec", test_conversation_codec)
    run_case(ledger, "core.prompt_prefix_exact", test_prompt_prefix)
    run_case(ledger, "core.dense_buffer_layout", test_dense_buffers)
    run_case(ledger, "tests.turing_fixture_plan", test_turing_fixture_plan)
    run_case(ledger, "tests.turing_fixture_control", test_turing_fixture_control)
    run_case(ledger, "tests.turing_replay_plan", test_turing_replay_plan)
    run_case(
        ledger, "cli.conversation_compatibility", test_conversation_compatibility
    )
    run_case(
        ledger, "cli.conversation_autosave_generations",
        test_conversation_autosave_generations,
    )
    run_case(
        ledger, "cli.conversation_autosave_corrupt_records",
        test_conversation_autosave_corrupt_records,
    )
    run_case(ledger, "cli.model_preferences_codec", test_model_preferences_codec)
    run_case(ledger, "cli.favorite_model_selection", test_model_favorite_selection)
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
    run_case(ledger, "quantization.q8_0_gemv_simd_known_value", test_q8_0_gemv_simd_known_value)
    run_case(ledger, "quantization.q8_0_gemv_simd_parity", test_q8_0_gemv_simd_parity)
    run_case(ledger, "quantization.q8_0_gemv_multirow_regression", test_q8_0_gemv_multirow_regression)
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
    run_case(ledger, "quantization.k_dequant_simd_q4_k_parity", test_k_dequant_simd_q4_k_parity)
    run_case(ledger, "quantization.k_dequant_simd_q5_k_parity", test_k_dequant_simd_q5_k_parity)
    run_case(ledger, "quantization.k_dequant_simd_q6_k_parity", test_k_dequant_simd_q6_k_parity)
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
    run_case(
        ledger,
        "quantization.exl2_mixedbit_known_value",
        test_exl2_mixedbit_known_value,
    )
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
    run_case(ledger, "quantization.iq1_s_known_value", test_iq1_s_known_value)
    run_case(
        ledger, "quantization.iq2_xxs_known_value", test_iq2_xxs_known_value
    )
    run_case(ledger, "quantization.iq2_s_known_value", test_iq2_s_known_value)
    run_case(ledger, "quantization.iq3_s_known_value", test_iq3_s_known_value)
    run_case(
        ledger, "quantization.iq2_xs_known_value", test_iq2_xs_known_value
    )
    run_case(
        ledger, "quantization.iq3_xxs_known_value", test_iq3_xxs_known_value
    )
    run_case(
        ledger,
        "quantization.tq1_0_known_value",
        test_tq1_0_known_value,
    )
    run_case(ledger, "quantization.iq_simd_parity_iq1_s", test_iq_simd_parity_iq1_s)
    run_case(ledger, "quantization.iq_simd_parity_iq1_m", test_iq_simd_parity_iq1_m)
    run_case(ledger, "quantization.iq_simd_parity_iq2_xxs", test_iq_simd_parity_iq2_xxs)
    run_case(ledger, "quantization.iq_simd_parity_iq2_xs", test_iq_simd_parity_iq2_xs)
    run_case(ledger, "quantization.iq_simd_parity_iq2_s", test_iq_simd_parity_iq2_s)
    run_case(ledger, "quantization.iq_simd_parity_iq3_xxs", test_iq_simd_parity_iq3_xxs)
    run_case(ledger, "quantization.iq_simd_parity_iq3_s", test_iq_simd_parity_iq3_s)
    run_case(ledger, "quantization.iq_simd_parity_iq4_nl", test_iq_simd_parity_iq4_nl)
    run_case(ledger, "quantization.iq_simd_parity_iq4_xs", test_iq_simd_parity_iq4_xs)
    run_case(ledger, "prefill.batching_policy", test_prefill_batching_policy)
    run_case(ledger, "prefill.batching_dense_range_parity", test_prefill_batching_dense_range_parity)
    run_case(ledger, "prefill.batching_dense_public_parity", test_prefill_batching_dense_public_parity)
    run_case(ledger, "prefill.batching_q8_range_parity", test_prefill_batching_q8_range_parity)
    run_case(ledger, "prefill.batching_q4_0_public_parity", test_prefill_batching_q4_0_public_parity)
    run_case(ledger, "chat_template.golden_chatml", test_chat_template_golden_chatml)
    run_case(ledger, "chat_template.golden_llama3", test_chat_template_golden_llama3)
    run_case(ledger, "chat_template.golden_llama2", test_chat_template_golden_llama2)
    run_case(ledger, "chat_template.golden_gemma", test_chat_template_golden_gemma)
    run_case(ledger, "chat_template.golden_family_routing", test_chat_template_golden_family_routing)
    run_case(ledger, "long_context.growth_account", test_long_context_growth_account)
    run_case(ledger, "long_context.session_cap_verdict", test_long_context_session_cap_verdict)
    run_case(ledger, "long_context.depths_patterns", test_long_context_depths_patterns)
    run_case(ledger, "long_context.probe_grading", test_long_context_probe_grading)
    run_case(ledger, "long_context.kv_growth_execution", test_long_context_kv_growth_execution)
    run_case(ledger, "long_context.needle_probes", test_long_context_needle_probes)
    run_case(ledger, "storage.z13_autosave_generations", test_storage_z13_autosave_generations)
    run_case(ledger, "storage.z13_state_vault_disk", test_storage_z13_state_vault_disk)
    run_case(ledger, "storage.z13_catalog_restart", test_storage_z13_catalog_restart)
    run_case(ledger, "storage.z13_conversation_snapshot", test_storage_z13_conversation_snapshot)
    run_case(ledger, "attention.gqa_simd_reference_parity", test_gqa_simd_reference_parity)
    run_case(ledger, "attention.gqa_simd_dyadic_bitwise", test_gqa_simd_dyadic_bitwise)
    run_case(ledger, "attention.gqa_simd_tail_parity", test_gqa_simd_tail_parity)
    run_case(ledger, "attention.gqa_simd_modifiers_parity", test_gqa_simd_modifiers_parity)
    run_case(ledger, "attention.gqa_simd_long_parity", test_gqa_simd_long_parity)
    run_case(
        ledger,
        "quantization.format_metadata",
        test_quantization_format_metadata,
    )
    run_case(
        ledger,
        "quantization.measured_autotuner",
        test_measured_quantized_gemm_autotuner,
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
    run_case(ledger, "resilience.error_guard_finiteness", test_error_guard_finiteness)
    run_case(ledger, "resilience.state_vault_marker", test_state_vault)
    run_case(
        ledger,
        "resilience.state_vault_read_exact_bytes",
        test_state_vault_read_exact_bytes,
    )
    run_case(
        ledger,
        "resilience.state_vault_rejects_growth",
        test_state_vault_rejects_growth,
    )
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
    run_case(
        ledger,
        "huggingface.resume_verification",
        test_hf_resume_completion_verification,
    )
    run_case(ledger, "cli.cuda_chat_admission", test_cuda_chat_admission)
    run_case(ledger, "cli.cuda_model_switch_syntax", test_cuda_model_switch_syntax)
    run_case(ledger, "cli.chat_recovery_policy", test_chat_recovery_policy)
    run_case(
        ledger,
        "cli.chat_recovery_snapshot_validation",
        test_chat_recovery_snapshot_validation,
    )
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
    run_case(ledger, "local_service.http_bounds", test_local_http_bounds)
    run_case(ledger, "local_service.http_framing", test_local_http_framing)
    run_case(ledger, "local_service.request", test_local_generation_request)
    run_case(ledger, "local_service.c_paths", test_local_path_bounds)
    run_case(ledger, "local_service.ollama_sampling_bounds", test_ollama_sampling_bounds)
    run_case(ledger, "local_service.gemma_tool_protocol", test_gemma_tool_protocol)
    run_case(ledger, "local_service.fd_ownership", test_owned_fd_transfer_release)
    run_case(ledger, "local_service.socket_admission", test_socket_admission_rejection)
    run_case(ledger, "local_service.socketpair_framing", test_socketpair_request_transport)
    run_case(ledger, "local_service.transport_adversarial", test_request_transport_adversarial)
    run_case(ledger, "native.gemma4_profiles", test_gemma4_profiles)
    run_case(ledger, "native.model_registry", test_model_architecture_registry)
    # Keep this final: Mojo 1.0.0 runtime crashes when another file-system-heavy
    # test runs after this caught-error adversarial path in the same process.
    run_case(ledger, "compute.rope_adversarial", test_rope_adversarial)
    # S-092 re-pin: 277 -> 278 for memory.dense_residency, registered by
    # the janas merges into 2444d610 without re-accounting this pin
    # (base control at 2444d610 counted 276/0/2/278 and failed here).
    # Union re-pin (merge-to-main sweep 2026-11-01): 278 -> 279 -- both sides' registrations counted (run_case + record_skip); the incoming branch's finish pin did not count its own added case.
    # Union re-pin (merge-to-main sweep 2026-11-01): 279 -> 280 -- both sides' registrations counted (run_case + record_skip); the incoming branch's finish pin did not count its own added case.
    # A-009 re-pin: 280 -> 284 for the four cli.backend_registry_* cases.
    # Union re-pin (A-009 banking 2026-11-12): 284 -> 290 -- both sides' registrations counted (run_case + record_skip); the seat already carried A-001's 6 census cases the incoming pin did not count.
    # A-001 catch-up: 280 -> 286 for the six hardware.census_* cases
    # A-001 registered without re-accounting this pin (baseline control
    # at e33b6f0d counted 283 passed / 1 failed / 2 skipped / 286 total
    # and failed on this pin alone).
    # A-010: 286 -> 288 for gpu.amd_hip_device_gate and
    # gpu.amd_hip_properties_parser.
    # Union re-pin (A-010 banking 2026-11-12): 290 -> 292 -- both sides' registrations counted (run_case + record_skip); the incoming A-001 catch-up was already carried by the seat, so only A-010's 2 cases move the seat pin.
    # A-011 re-pin: 280 -> 285 -- five HIP memory cases added
    # (gpu.amd_hip_* in tests/test_amd_realm.mojo).
    # Union re-pin (A-011 banking 2026-11-12): 292 -> 297 -- both sides' registrations counted (run_case + record_skip); A-011's amd_gate soname hunk was already subsumed by A-010's versioned-first probe, so the seat amd_gate is kept.
    # A-012 re-pin: 285 -> 290 -- five HIP transfer + streams cases added
    # (gpu.amd_hip_sync_oracle_round_trip, gpu.amd_hip_stream_*,
    # gpu.amd_hip_event_timing in tests/test_amd_realm.mojo).
    # Union re-pin (A-012 banking 2026-11-12): 297 -> 302 -- both sides' registrations counted (run_case + record_skip); only A-012's own diff was banked (its parent fab684da is a cherry-pick twin of A-011 and was not re-banked).
    # A-013 re-pin: 280 -> 284 for the four gpu.vulkan_* cases
    # (context create, taxonomy mapping, forced-failure taxonomy,
    # local rejection) registered by the A-013 slice.
    # Union re-pin (A-013 banking 2026-11-12): 302 -> 306 -- both sides' registrations counted (run_case + record_skip).
    # A-014 re-pin: 280 -> 284 -- four Vulkan buffer cases added
    # (gpu.vulkan_buffer_* in tests/test_vulkan_buffers.mojo), counted
    # on this branch's ba0cf066 base; the union total reconciles at
    # banking after A-011/A-012 land ahead of this slice.
    # Union re-pin (A-014 banking 2026-11-12): 306 -> 310 -- both sides' registrations counted (run_case + record_skip).
    # A-015 re-pin: 310 -> 313 -- three Vulkan dispatch cases added
    # (gpu.vulkan_dispatch_* in tests/test_vulkan_dispatch.mojo).
    # Union re-pin (A-017 banking 2026-11-12): 313 -> 319 -- six
    # cli.device_policy_* cases (accelerator-first, GPU backend
    # fallback, CPU spillover/none, override, NPU proven path,
    # deterministic log) in tests/test_device_policy.mojo, counted
    # on top of A-015 pin at banking.
    # A-018 re-pin: 319 -> 323 -- four thermal.* cases added
    # (thermal.hwmon_parsers, thermal.tolerance_tracking,
    # thermal.lines_fixture, thermal.live_sensors in
    # tests/test_thermal_power.mojo).
    # Union re-pin (A-019 banking 2026-11-12): 323 -> 328 -- five
    # zero-copy allocator cases (gpu.zero_copy_* in
    # tests/test_zero_copy.mojo) counted on top of A-018 pin.
    # A-020 re-pin: 319 -> 323 -- four weight residency cases added
    # (gguf.weight_residency_* in tests/test_weight_residency.mojo),
    # counted on this branch's da2cf9d8 base (seat pin 319); the union
    # total reconciles at banking.
    # Union re-pin (A-020 banking 2026-11-12): 328 -> 332 -- four
    # weight residency cases counted on top of A-019 pin.
    # Re-pin (A-021): 328 -> 334 -- six KV-cache-in-unified-memory
    # cases (gpu.kv_unified_* in tests/test_kv_unified.mojo).
    # Union re-pin (A-021 banking 2026-11-12): 332 -> 338 -- six
    # kv_unified cases counted on top of A-020 pin.
    # A-022 re-pin: 328 -> 332 -- four buffer ownership law cases
    # (gpu.buffer_ownership_* in tests/test_buffer_ownership.mojo)
    # counted on top of A-019 pin.
    # Union re-pin (A-022 banking 2026-11-12): 338 -> 342 -- four
    # buffer ownership cases counted on top of A-021 pin.
    # A-023 re-pin: 328 -> 334 -- six memory budget governor cases
    # (memory.budget_* in tests/test_memory_budget.mojo).
    # Union re-pin (A-023 banking 2026-11-12): 342 -> 348 -- six
    # memory budget governor cases counted on top of A-022 pin.
    # Union re-pin (A-024 banking 2026-11-12): 348 -> 354 -- six
    # thread placement cases counted on top of A-023 pin.
    # Union re-pin (A-026 banking 2026-11-12): 354 -> 359 -- five
    # arena allocator cases counted on top of A-024 pin.
    # Re-pin (A-029): 359 -> 362 -- three Mojo-native GPU target
    # cases (gpu.mojo_native_* in tests/test_mojo_gpu_target.mojo).
    # A-032 re-pin: 362 -> 368 -- six backend config surface cases
    # (cli.backend_config_* in tests/test_backend_config.mojo).
    # A-033 re-pin: 362 -> 367 -- five structured-error cases added
    # (errors.structured_* in tests/test_structured_errors.mojo).
    # Union re-pin (A-033 banking 2026-11-12): 368 -> 373 -- five
    # structured-error cases counted on top of the A-032 pin.
    # Re-pin (A-036): 362 -> 366 -- four phase timing cases
    # (timing.phase_* in tests/test_phase_timing.mojo).
    # Union re-pin (A-036 banking 2026-11-12): 373 -> 377 -- four
    # phase timing cases counted on top of the A-033 seat pin.
    # A-038 re-pin: 373 -> 376 -- three Q8_0 GEMV SIMD cases
    # (quantization.q8_0_gemv_* in tests/test_q8_0_gemv_simd.mojo)
    # counted on top of the A-033 union pin.
    # Union re-pin (A-038 banking 2026-11-12): 377 -> 380 -- three
    # Q8_0 GEMV SIMD cases counted on top of the A-036 seat pin.
    # A-039 re-pin: 373 -> 382 -- nine wide-SIMD IQ dequant parity
    # cases (quantization.iq_simd_parity_* in
    # tests/test_iq_simd_parity.mojo), one per IQ format present.
    # Union re-pin (A-039 banking 2026-11-12): 380 -> 389 -- nine
    # IQ SIMD parity cases counted on top of the A-038 seat pin.
    # Re-pin (A-040): 377 -> 380 -- three SIMD K-dequant bit-parity
    # cases (quantization.k_dequant_simd_* in
    # tests/test_k_dequant_simd_a040.mojo).
    # Union re-pin (A-040 banking 2026-11-12): 389 -> 392 -- three
    # K-dequant SIMD cases counted on top of the A-039 seat pin.
    # A-041 re-pin: 389 -> 395 -- six thread scaling law cases
    # (cpu.thread_scaling_* in tests/test_thread_scaling.mojo).
    # Union re-pin (A-041 banking 2026-11-12): 392 -> 398 -- six
    # thread scaling cases counted on top of the A-040 seat pin.
    # A-042 re-pin: 389 -> 394 -- five prefill batching audit
    # cases (prefill.* in tests/test_prefill_batching.mojo).
    # Union re-pin (A-042 banking 2026-11-12): 398 -> 403 -- five
    # prefill batching cases counted on top of the A-041 seat pin.
    # A-043 re-pin: 403 -> 408 -- five fused-attention SIMD parity
    # cases (attention.gqa_simd_* in
    # tests/test_fused_attention_a043.mojo).
    # A-044 re-pin: 403 -> 408 -- five sampling cost parity cases
    # (sampling_cost.* in tests/test_sampling_cost_a044.mojo).
    # Union re-pin (A-044 banking 2026-11-12): 408 -> 413 -- five
    # sampling cost cases counted on top of the A-043 seat pin.
    # A-045 re-pin (A-047 banking 2026-11-12): 418 -> 424 -- six
    # precision path cases (precision.* in
    # tests/test_precision_paths.mojo) counted on top of the
    # A-045 seat pin.
    # A-050 re-pin: 424 -> 430 -- six tokenizer edge battery cases
    # (tokenizer.edge_* in tests/test_tokenizer_edge_a050.mojo).
    # Union re-pin (A-051 banking 2026-11-12): 430 -> 435 -- five
    # chat-template golden cases (chat_template.golden_* in
    # tests/test_chat_template_goldens_a051.mojo) counted on top
    # of the A-050 seat pin.
    # A-052 re-pin: 435 -> 441 -- six long-context cases
    # (long_context.* in tests/test_long_context_a052.mojo)
    # counted on top of the A-051 seat pin.
    # Union re-pin (A-053 banking 2026-11-12): 441 -> 445 -- four
    # Z13 storage cases (storage.z13_* in
    # tests/test_state_storage_a053.mojo) counted on top of the
    # A-052 seat pin.
    # A-055 re-pin: 445 -> 450 -- five SPIR-V pipeline cases added
    # (gpu.spirv_pipeline_* in tests/test_spirv_pipeline_a055.mojo)
    # counted on top of the A-053 union pin at the b62b1481 seat.
    # Union re-pin (A-056 banking 2026-11-12): 450 -> 455 -- five
    # Vulkan Q8_0 GEMV cases (gpu.vulkan_q8_gemv_* in
    # tests/test_vulkan_q8_gemv.mojo) counted on top of the
    # A-055 seat pin.
    # Union re-pin (A-057 banking 2026-11-12): 455 -> 458 -- three
    # Vulkan Q4_K GEMV cases (gpu.vulkan_q4k_gemv_* in
    # tests/test_vulkan_q4k_gemv_a057.mojo) counted on top of the
    # A-056 seat pin.
    # Union re-pin (A-058 banking 2026-11-12): 458 -> 463 -- five
    # Vulkan Q6_K + Q5_K GEMV cases (gpu.vulkan_q6k_q5k_* in
    # tests/test_vulkan_q6k_q5k_gemv.mojo) counted on top of the
    # A-057 seat pin.
    # Union re-pin (A-059 banking 2026-11-12): 463 -> 468 -- five
    # Vulkan IQ GEMV cases (gpu.vulkan_iq_gemv_* in
    # tests/test_vulkan_iq_gemv.mojo) counted on top of the
    # A-058 seat pin.
    # Union re-pin (A-060 banking 2026-11-12): 468 -> 474 -- six
    # Vulkan RMSNorm + RoPE cases (gpu.vulkan_rmsnorm_* /
    # gpu.vulkan_rope_* in tests/test_vulkan_rmsnorm_rope_a060.mojo)
    # counted on top of the A-059 seat pin.
    # A-061 (team-02): 463 -> 469 -- six Vulkan elementwise +
    # softmax cases (gpu.vulkan_elementwise_* / gpu.vulkan_softmax_*
    # in tests/test_vulkan_elementwise_softmax_a061.mojo) counted
    # on top of the A-058 seat pin on this branch's base; the
    # union total reconciles at banking.
    # Union re-pin (A-061 banking 2026-11-12): 474 -> 480 -- six
    # Vulkan elementwise + softmax cases counted on top of the
    # A-060 seat pin.
    # A-062 re-pin: 463 -> 468 -- five Vulkan decode attention
    # cases (gpu.vulkan_attn_decode_* in
    # tests/test_vulkan_attention_a062.mojo) counted on top of
    # the A-058 seat pin.
    # Union re-pin (A-062 banking 2026-11-12): 480 -> 485 -- five
    # Vulkan decode attention cases counted on top of the
    # A-061 seat pin.
    # A-063 re-pin: 485 -> 491 -- six Vulkan sampling cases
    # (gpu.vulkan_sampling_* in
    # tests/test_vulkan_sampling_a063.mojo) counted on top of
    # the A-062 seat pin.
    # A-064 re-pin: 485 -> 490 -- five GPU weight residency
    # cases (gpu.gpu_weight_residency_* in
    # tests/test_gpu_weight_residency_a064.mojo) counted on top
    # of the A-062 seat pin on this branch base; A-063 is built
    # in parallel on the same base and the union total
    # reconciles at banking.
    # A-065 union re-pin (banking 2026-11-12): 496 -> 501 --
    # five Vulkan full layer cases (gpu.vulkan_layer_* in
    # tests/test_vulkan_layer_a065.mojo) counted on top of the
    # A-064 seat pin.
    # A-068 union re-pin (banking 2026-11-12): 512 -> 518 --
    # six Vulkan prefill GEMM cases
    # (gpu.vulkan_prefill_gemm_* in
    # tests/test_vulkan_gemm_a068.mojo) counted on top of the
    # A-067 seat pin (A-068 team pin was 501 -> 507 on its
    # own base; the union total reconciles at banking).
    # A-069 re-pin: 518 -> 525 -- seven chunked prefill cases
    # (gpu.vulkan_chunked_prefill_* in
    # tests/test_vulkan_prefill_a069.mojo) counted on top of
    # the A-068 seat pin.
    # A-070 union re-pin (banking 2026-11-12): 525 -> 531 --
    # six lawful CPU assist cases (cpu_assist.* in
    # tests/test_cpu_assist_a070.mojo) counted on top of the
    # A-069 seat pin (A-070 team pin was 518 -> 524 on its
    # own base; the union total reconciles at banking).
    # A-071 union re-pin (banking 2026-11-12): 531 -> 537 --
    # six Vulkan async dispatch cases (gpu.vulkan_async_* in
    # tests/test_vulkan_async_a071.mojo) counted on top of the
    # A-070 seat pin (A-071 team pin was 518 -> 524 on its
    # own base; the union total reconciles at banking).
    # A-072 union re-pin (banking 2026-11-12): 537 -> 543 --
    # six continuous batching cases
    # (gpu.vulkan_continuous_batch_* in
    # tests/test_vulkan_batch_a072.mojo) counted on top of
    # the A-071 seat pin (A-072 team pin was 531 -> 537 on its
    # own base; the union total reconciles at banking).
    # A-075 re-pin: 543 -> 549 -- six accumulation policy cases
    # (accum_policy.* in tests/test_accum_policy_a075.mojo) counted
    # on top of the A-073 seat pin (A-075 team pin; the union total
    # reconciles at banking).
    # A-076 union re-pin (banking 2026-11-12): 549 -> 556 -- seven
    # GPU memory pressure cases (gpu.gpu_pressure_* in
    # tests/test_gpu_pressure_a076.mojo) counted on top of the
    # A-075 seat pin; the A-076 team pin (550 on the A-073 base)
    # reconciles here at banking.
    # A-077 re-pin: 556 -> 561 -- five GPU soak cases
    # (gpu.gpu_soak_* in tests/test_gpu_soak_a077.mojo)
    # counted on top of the A-076 seat pin.
    # A-078 union re-pin (banking 2026-11-12): 561 -> 568 --
    # seven GPU fuzz cases (gpu_fuzz.* in
    # tests/test_gpu_fuzz_a078.mojo) counted on top of the
    # A-077 seat pin; the A-078 team pin (563 on the A-076
    # base) reconciles here at banking.
    # A-079 union re-pin (banking 2026-11-12): 568 -> 575 --
    # seven device-lost recovery cases (gpu.device_lost_*
    # in tests/test_device_lost_a079.mojo) counted on top of
    # the A-078 seat pin; the A-079 team pin (563 on the
    # A-076 base) reconciles here at banking.
    # A-080 union re-pin (banking 2026-11-13): 575 -> 581 --
    # six equivalence gate cases (equivalence.* in
    # tests/test_equivalence_gate_a080.mojo) counted on top
    # of the A-079 seat pin; the A-080 team pin (574 on the
    # A-078 base) reconciles here at banking.
    # A-082 union re-pin (banking 2026-11-13): 581 -> 586 --
    # five HIP Q8_0 GEMV cases (gpu.hip_q8_gemv_* in
    # tests/test_hip_q8_gemv_a082.mojo) counted on top
    # of the A-081 seat pin; the A-082 team pin (573 on
    # the A-078 base) reconciles here at banking.
    # A-083 union re-pin (banking 2026-11-13): 586 -> 589 --
    # three HIP Q4_K GEMV cases (gpu.hip_q4k_gemv_* in
    # tests/test_hip_q4k_gemv_a083.mojo) counted on top
    # of the A-082 seat pin; the A-083 team pin (571 on
    # the A-078 base) reconciles here at banking.
    # A-084 union re-pin (banking 2026-11-13): 589 -> 594 --
    # five HIP attention + norms cases (gpu.hip_attn_norms_*
    # in tests/test_hip_attn_norms_a084.mojo) counted on top
    # of the A-083 seat pin; the A-084 team pin (591 on the
    # A-082 base) reconciles here at banking.
    # A-086 union re-pin (banking 2026-11-13): 594 -> 600 --
    # six winner-integration cases (gpu_winner.* in
    # tests/test_gpu_winner_a086.mojo) counted on top of the
    # A-085 seat pin; the A-086 team pin (595 on the A-083
    # base) reconciles here at banking. The banked A-085
    # verdict (Vulkan first-class, HIP probe-only) is applied
    # to the live registry at the seat in this banking.
    # A-087 union re-pin (banking 2026-11-13): 600 -> 605 --
    # five ROCm install reproducibility cases (rocm_repro.* in
    # tests/test_rocm_repro_a087.mojo) counted on top of the
    # A-086 seat pin; the A-087 team pin (594 on the A-083
    # base) reconciles here at banking.
    # A-089 union re-pin (banking 2026-11-13): 605 -> 610 --
    # five HIP error semantics cases (errors.hip_* in
    # tests/test_hip_errors_a089.mojo) counted on top of the
    # A-088 seat pin; the A-089 team pin (599 on the A-085
    # base) reconciles here at banking.
    # A-100 re-pin: 610 -> 616 -- six placement planner cases
    # (planner.* in tests/test_placement_planner_a100.mojo)
    # counted on top of the A-099 seat pin.
    # A-101 union re-pin at banking: 616 -> 622 -- six pipeline
    # overlap cases (pipeline.overlap_* in
    # tests/test_pipeline_overlap_a101.mojo) counted on top of
    # the A-100 seat pin.
    # A-102 union re-pin at banking: 622 -> 629 -- seven
    # spillover policy cases (sched.spillover_* in
    # tests/test_spillover_policy_a102.mojo) counted on top of
    # the A-101 seat pin (team branch pin was 617 on the
    # A-099 base; union reconciled here per the A-102 note).
    # A-103 union re-pin at banking: 629 -> 636 -- seven
    # mid-run failure re-planning cases (replan.* in
    # tests/test_failure_replan_a103.mojo) counted on top of
    # the A-102 seat pin (team branch pin was 629 on the
    # A-101 base; union reconciled here at banking).
    # A-104 union re-pin at banking: 636 -> 642 -- six
    # big-model placement cases (placement.big_model_* in
    # tests/test_big_model_placement_a104.mojo) counted on top
    # of the A-103 seat pin (team branch pin was 628 on the
    # A-101 base; union reconciled here at banking).
    # A-105 union re-pin at banking: 642 -> 650 -- eight
    # two-model fairness cases (sched.fairness_* in
    # tests/test_fairness_a105.mojo) counted on top of the
    # A-104 seat pin (team branch pin was 637 on the A-102
    # base; union reconciled here at banking).
    # A-106 re-pin (team-27): 650 -> 658 -- eight scheduler
    # telemetry cases (sched.telemetry_* in
    # tests/test_telemetry_a106.mojo) counted on top of the
    # A-105 seat pin; the union reconciles at banking.
    # A-107 union re-pin at banking: 658 -> 664 -- six
    # placement regression battery cases (battery.* in
    # tests/test_placement_regression_a107.mojo) counted on
    # top of the A-106 seat pin (team branch pin was 656 on
    # the A-105 base; union reconciled here at banking).
    # A-109 (team-25): 670 -> 677 -- seven teacher-forcing
    # harness v2 cases (oracle.tf_* in
    # tests/test_teacher_forcing_harness_a109.mojo) counted
    # on top of the A-108 seat pin; the union reconciles at
    # banking.
    # A-108 union re-pin at banking: 664 -> 670 -- six
    # Part IV gate cases (gate.part_iv_* in
    # tests/test_part_iv_gate_a108.mojo) counted on top of
    # the A-107 seat pin (team branch pin was 656 on the
    # A-105 base; union reconciled here at banking).
    # A-110 re-pin (team-26): 670 -> 677 -- seven oracle pin
    # registry cases (oracle.pin_* in
    # tests/test_oracle_pins_a110.mojo) counted on top of the
    # A-108 seat pin (team branch pin reconciles at banking;
    # A-109/A-111 build in parallel on the same base).
    # A-110 union re-pin at banking: 677 -> 684 -- the seven
    # oracle.pin_* cases counted on top of the A-109 seat pin
    # (team branch pin was 677 on the A-108 base; union
    # reconciled here at banking).
    # A-111 re-pin (team-27): 670 -> 681 -- eleven
    # near-tie gate cases (gate.near_tie_* in
    # tests/test_near_tie_gate_a111.mojo) counted on top
    # of the A-108 seat pin; the union reconciles at
    # banking.
    # A-111 union re-pin at banking: 684 -> 695 -- the
    # eleven gate.near_tie_* cases counted on top of the
    # A-110 seat pin (team branch pin was 681 on the A-108
    # base; union reconciled here at banking).
    ledger.finish(695)
