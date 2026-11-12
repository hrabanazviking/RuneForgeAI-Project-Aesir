/* buffer_ownership.h - Buffer ownership law (slice A-022).
 *
 * THE LAW (full text in hidden_files/A022_LEDGER.md):
 *  1. Every buffer has exactly ONE owner at any moment. Ownership is a
 *     registry entry inside the allocating shim; a raw pointer, fd, or
 *     native handle is only a capability to look that entry up - it is
 *     never ownership itself.
 *  2. States: LIVE (owned) -> HANDED_OFF (sender tombstone; the
 *     receiver must claim before any use) -> LIVE under the receiver;
 *     LIVE -> FREED (tombstone, retained so a second free is
 *     DETECTABLE instead of silent). No other transitions exist.
 *  3. Borrowed views (a pointer/fd passed for the duration of one
 *     call, a vkMapMemory mapping, an XRT BO map) never own: they may
 *     never free, close, hand off, or outlive a checked use. Free and
 *     hand-off are refused while a borrow is active (XRT contract
 *     layer; Vulkan free auto-unmaps its own mapping, which is the
 *     shim's own borrow, not a caller's).
 *  4. A handle is valid only for its own kind, its own allocating
 *     shim (device/backend), and its own generation. Cross-kind,
 *     cross-shim, stale-generation, foreign, and interior pointers
 *     are refused BEFORE any driver call.
 *  5. Fail closed, always: every refusal returns one of the named
 *     codes below as a value. Nothing crashes, nothing aborts, and a
 *     refused operation changes no state and no counter except the
 *     shim's ownership-violation counter. The underlying driver free
 *     (hipFree / vkDestroyBuffer / vkFreeMemory / xrtBOFree) runs
 *     exactly once, inside the single LIVE -> FREED transition.
 *  6. Leak accounting is the existing per-shim live-byte accounting
 *     (A-014 Vulkan g_live_bytes, A-019 ZeroCopy g_live_bytes, and the
 *     A-022 HIP registry counters); it moves only on a successful
 *     alloc or the single successful free transition, so it returns
 *     to baseline after every adversarial sequence.
 *
 * Taxonomy mapping (ERROR_TAXONOMY.md): the MEM-004/MEM-005 codes are
 * the taxonomy's own; at the shim/API boundary they are returned as
 * recoverable caller errors (the taxonomy's Fatal disposition governs
 * internal origin-checker bugs, not caller misuse - the A-022 ledger
 * records this boundary ruling and the proposed MEM-011..MEM-015
 * boundary codes below for the taxonomy's next revision).
 */
#ifndef AESIR_BUFFER_OWNERSHIP_H
#define AESIR_BUFFER_OWNERSHIP_H

/* Registry entry states. */
#define AESIR_OWN_STATE_EMPTY 0
#define AESIR_OWN_STATE_LIVE 1
#define AESIR_OWN_STATE_HANDED_OFF 2
#define AESIR_OWN_STATE_FREED 3

/* Named fail-closed results (all negative; 0 = success). */
#define AESIR_OWN_DOUBLE_FREE (-22005)       /* MEM-005 DOUBLE_FREE */
#define AESIR_OWN_USE_AFTER_FREE (-22004)    /* MEM-004 USE_AFTER_FREE */
#define AESIR_OWN_USE_AFTER_HANDOFF (-22011) /* MEM-011 (boundary) */
#define AESIR_OWN_CROSS_DEVICE (-22012)      /* MEM-012 (boundary): cross-kind / cross-shim / cross-device misuse */
#define AESIR_OWN_NOT_OWNER (-22013)         /* MEM-013 (boundary): foreign or never-owned handle */
#define AESIR_OWN_STALE_HANDLE (-22014)      /* MEM-014 (boundary): generation mismatch / ABA */
#define AESIR_OWN_INVALID (-22015)           /* invalid ownership argument */

#endif /* AESIR_BUFFER_OWNERSHIP_H */
