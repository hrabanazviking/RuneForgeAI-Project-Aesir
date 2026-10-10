# VÖRÐR staging-buffer integrity (H154).
#
# Every DMA/staging payload is checksummed at rest and VERIFIED
# before compute consumes it. A mismatch emits IntegrityCorrupt and
# the buffer is re-transferred from the pristine copy (transient per
# the taxonomy); the re-transferred data must verify clean before use
# resumes. Checksum: FNV-1a 64-bit, pure Mojo (L1 — no libraries).
#
# In the NO-GO branch the "transfers" are host-side staging buffers
# (there is no NPU DMA); the detection assertions are identical.

from hailbru.errors import herror
from std.memory.alloc import unsafe_alloc
from std.memory import Pointer
from std.origin import MutUntrackedOrigin
from vordr.events import event_emit_slice


def fnv1a64(p: Pointer[UInt8, MutUntrackedOrigin], n: Int) -> UInt64:
    var h = UInt64(14695981039346656037)
    for i in range(n):
        h ^= UInt64(p[unsafe_offset=i])
        h *= UInt64(1099511628211)
    return h


struct StagingBuffer:
    # A staging payload with its pristine copy and checksum.
    # verify() MUST be called before compute consumes the payload;
    # corrupt payloads never reach compute (H154: escape count = 0).
    var data: Pointer[UInt8, MutUntrackedOrigin]
    var pristine: Pointer[UInt8, MutUntrackedOrigin]
    var n: Int
    var sum: UInt64
    var name: String
    var freed: Bool

    def __init__(
        out self, name: String, n: Int, fill_seed: UInt64
    ):
        self.n = n
        self.name = name
        self.freed = False
        self.data = unsafe_alloc[UInt8](n)
        self.pristine = unsafe_alloc[UInt8](n)
        var s = fill_seed
        for i in range(n):
            # splitmix64 stream, deterministic.
            s += UInt64(0x9E3779B97F4A7C15)
            var z = s
            z = (z ^ (z >> 30)) * UInt64(0xBF58476D1CE4E5B9)
            z = (z ^ (z >> 27)) * UInt64(0x94D049BB133111EB)
            z = z ^ (z >> 31)
            var b = UInt8(z & UInt64(0xFF))
            self.data[unsafe_offset=i] = b
            self.pristine[unsafe_offset=i] = b
        self.sum = fnv1a64(self.data, n)

    def verify(
        mut self, arch: String, log_path: String
    ) raises -> Bool:
        # True = clean. False = corruption DETECTED (event emitted);
        # the caller must retransfer() before consuming.
        var now = fnv1a64(self.data, self.n)
        if now == self.sum:
            return True
        event_emit_slice(
            arch, log_path, "H154", "IntegrityCorrupt",
            "\"buffer\": \"" + self.name + "\", \"expected_sum\": "
            + String(self.sum) + ", \"actual_sum\": " + String(now),
        )
        return False

    def retransfer(mut self, arch: String, log_path: String) raises:
        # Restore from the pristine copy; MUST verify clean after.
        for i in range(self.n):
            self.data[unsafe_offset=i] = self.pristine[unsafe_offset=i]
        var now = fnv1a64(self.data, self.n)
        if now != self.sum:
            raise herror(
                "RetransferFailed",
                "re-transferred buffer '" + self.name
                + "' still corrupt — fail closed",
            )
        event_emit_slice(
            arch, log_path, "H154", "IntegrityRetransferred",
            "\"buffer\": \"" + self.name + "\", \"bytes\": "
            + String(self.n) + ", \"verify\": \"clean\"",
        )

    def corrupt_bit(mut self, bit_index: Int):
        # TEST HOOK (H154 fault injection): flip one bit.
        var byte_i = bit_index // 8
        var bit_i = bit_index % 8
        var b = self.data[unsafe_offset=byte_i]
        self.data[unsafe_offset=byte_i] = b ^ UInt8(1 << bit_i)

    def free(mut self):
        if not self.freed:
            self.data.unsafe_free()
            self.pristine.unsafe_free()
            self.freed = True
