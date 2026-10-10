# VÖRÐR — D6 robustness / self-healing domain (MÍMISBRUNNR Campaign 8).
#
# The warden. VÖRÐR supervises the F1 CPU inference engine and the
# Hailo-10 device's health (H111 was NO-GO: the device is present but
# not computing). Health monitoring, watchdog/supervisor, device
# reset/re-init, error taxonomy, crash-resistant recovery, CPU
# shadow-verification.
#
# ARCHITECTURAL LAW (L6/L12): VÖRÐR COMMANDS resets only through
# HAILBRÚ's public interface (hailbru.api.reset); it never touches
# device nodes, BARs, or registers itself. grep-audited in H147.
#
# Modules:
#   health_obs  — H087 hooks (adopted from hailbru/ in H141)
#   events      — structured JSONL event log primitives
#   monitor     — periodic health-monitor loop (H141), thermal (H142)
#   hang        — inference heartbeat / hang detection (H143)
#   errdecode   — error-register polling + decode (H144)
#   taxonomy    — machine-readable error classification (H145)
#   spawn       — POSIX process primitives for the supervisor (H146)
#   watchdog    — crash-resistant supervisor process (H146)
#   reset_ctl   — VÖRÐR-commanded device reset (H147)
#   reinit      — post-reset re-initialization (H148)
#   recovery    — crash-resistant recovery state machine (H149)
#   shadow      — CPU shadow-verification sampler, NO-GO honest (H150)
#   integrity   — staging-buffer checksums, DMA-corrupt catch (H154)
#   retry       — transient-error retry with backoff (H156)
#   degrade     — CPU stage retry/fallback, honest degrade (H157)
#   testhooks   — fault-injection hooks (H151–H154 PRÓF drivers)
