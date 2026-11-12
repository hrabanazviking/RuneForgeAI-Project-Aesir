# core/prefill_batching.mojo
# Prefill batching policy (slice A-042): which execution path a
# multi-row prefill takes through the CPU GEMMs, decided from the
# A-042 audit measurements on this machine (Zen 5 / Strix Halo),
# filed in docs/bench/A042_PREFILL_BATCHING_AUDIT.md and
# hidden_files/A042_LEDGER.md (bench_prefill_batching_a042 +
# bench_prefill_e2e_a042).
#
# The audit question (roadmap A-042): batched GEMM vs row-by-row
# on Zen 5, measured honestly -- the wave lessons say batched
# prefill buys less than decode work, so verify, don't assume.
# The two paths, per weight format, in core/compute.mojo:
#   BATCHED: one GEMM call with A.rows == chunk length. The fast
#     ranges (dense F16 _gemm_f16_dense_range, Q8_0 decode-once
#     _gemm_q8_0_fast_range, K/IQ/TQ fast ranges) decode or read
#     each weight row once and dot it against every A row, and
#     par_for pays its dispatch cost once per GEMM.
#   ROW_BY_ROW: A.rows == 1 calls, one per token (the decode
#     shape). Quantized weights are re-decoded for every token;
#     the fused single-row ranges (A-038 _gemm_q8_0_gemv_range)
#     skip scratch setup but cannot amortize anything.
# Legacy scalar formats (Q4_0/Q4_1/Q5_0/Q5_1/Q8_1/FP8) have no
# separate batched body: their GEMM is one serial loop over rows,
# so a batched call and row-by-row calls execute identical inner
# work (the A-042 bench files this parity-of-cost explicitly);
# the policy below still routes them batched, which costs nothing
# and keeps one code path for prefill.
#
# Policy (the A-042 acceptance rule -- the better path is the
# default): rows >= PREFILL_BATCHED_MIN_ROWS takes the BATCHED
# path; a single row is the decode shape and takes ROW_BY_ROW.
# The engine facade's chunk cap default (AesirEngine.
# _prefill_batch_cap, aesir.mojo) is PREFILL_DEFAULT_CHUNK_CAP,
# the same 256 the S-033 evidence chose; AESIR_PREFILL_BATCH=1
# remains the operator override that restores the per-token loop.
#
# Fail-closed: row counts <= 0 raise; nothing is clamped.

comptime PREFILL_PATH_ROW_BY_ROW = 0
comptime PREFILL_PATH_BATCHED = 1

# Smallest row count that takes the batched path. At rows == 1
# the two paths are the same call; at every rows >= 2 measured
# in the A-042 audit the batched path won or tied on every
# format with a distinct batched body, so the threshold is 2.
comptime PREFILL_BATCHED_MIN_ROWS = 2

# Default prefill chunk cap (tokens per batched forward pass)
# when AESIR_PREFILL_BATCH is unset. Mirrors the facade default
# in aesir.mojo (_prefill_batch_cap); the A-042 tests pin the
# two together by value.
comptime PREFILL_DEFAULT_CHUNK_CAP = 256


def prefill_path_for_rows(rows: Int) raises -> Int:
    """Execution path for a prefill chunk of `rows` tokens:
    PREFILL_PATH_BATCHED for rows >= PREFILL_BATCHED_MIN_ROWS,
    PREFILL_PATH_ROW_BY_ROW for a single row. Raises on
    rows <= 0 (fail-closed, no clamping)."""
    if rows <= 0:
        raise Error("prefill_path_for_rows: rows must be positive")
    if rows >= PREFILL_BATCHED_MIN_ROWS:
        return PREFILL_PATH_BATCHED
    return PREFILL_PATH_ROW_BY_ROW


def prefill_uses_batched(rows: Int) raises -> Bool:
    """True iff a prefill chunk of `rows` tokens takes the
    batched GEMM path under the A-042 policy."""
    return prefill_path_for_rows(rows) == PREFILL_PATH_BATCHED


def prefill_default_chunk_cap() -> Int:
    """Default prefill chunk cap (see PREFILL_DEFAULT_CHUNK_CAP)."""
    return PREFILL_DEFAULT_CHUNK_CAP
