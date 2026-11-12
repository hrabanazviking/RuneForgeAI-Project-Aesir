# core/oversized_streaming.mojo
# Oversized-model streaming (slice A-049): a model too large for
# comfortable residency is consumed through its GGUF mmap in bounded
# windows, never by copying or faulting the whole file into anonymous
# memory.
#
# What the loader already does (loader/gguf.mojo): the whole file is
# one read-only mmap; F16 / quantized tensors are zero-copy views into
# it, so a tensor's bytes cost resident pages only when a pass actually
# touches them. What was missing -- and what this module adds -- is the
# *discipline and the accounting* for oversized files:
#
# - sweep_region() walks a mapped region sequentially in fixed
#   windows, checksumming what it touches (the touch IS the read: page
#   faults bring exactly the window in). After each window it issues
#   madvise(MADV_DONTNEED) over the window behind the read cursor, so
#   resident bytes stay bounded by the window instead of growing to
#   the file size, and madvise(MADV_WILLNEED) over the next window so
#   the kernel prefetches it while the current one is consumed.
# - Every counter is measured, not asserted: bytes streamed and bytes
#   dropped are counted by the sweep itself; resident bytes come from
#   the OS -- process VmRSS and the weight mapping's smaps resident
#   bytes, both through core.weight_residency (A-020, /proc-backed).
# - touch_region() is the control: the same sequential checksum with
#   no dropping. On a file that fits, its mapping resident grows to
#   the region size; the sweep's does not. The A-049 bench files both
#   legs on the 40 GiB oversized fixture (docs/bench/
#   A049_OVERSIZED_STREAMING.md); streaming is claimed from that OS
#   accounting, never from code structure alone.
#
# Honest limits: madvise is advisory by definition -- MADV_DONTNEED on
# a clean file-backed page discards it (a later touch re-faults from
# disk), which is exactly the residency bound claimed here; nothing in
# this module promises the kernel's readahead policy, only the window
# discipline and its measured effect. The generation leg of A-049 runs
# the ordinary engine forward path over the same mmap; this module
# does not change any compute.

from std.ffi import external_call
from std.memory import Pointer

from core.mimir_well import MutUntrackedOrigin
from core.weight_residency import WeightResidency
from loader.gguf import GGUFSeer

# Linux madvise advice values (sys/mman.h).
comptime MADV_NORMAL = 0
comptime MADV_RANDOM = 1
comptime MADV_SEQUENTIAL = 2
comptime MADV_WILLNEED = 3
comptime MADV_DONTNEED = 4

comptime PAGE_BYTES = 4096
comptime _PROT_READ = 1
comptime _MAP_PRIVATE = 2
comptime _O_RDONLY = 0
comptime _SEEK_END = 2

# FNV-1a 64-bit constants. checksum_range folds one UInt64 word per
# step (little-endian, as loaded), so the checksum is a word-wise
# FNV-1a: deterministic for a given byte string, and identical between
# the sweep and control legs over the same region.
comptime _FNV_OFFSET: UInt64 = 14695981039346656037
comptime _FNV_PRIME: UInt64 = 1099511628211


def _cstring(value: String) -> List[Int8]:
    var result = List[Int8]()
    var source = value.as_bytes()
    for index in range(len(source)):
        result.append(Int8(source[index]))
    result.append(0)
    return result^


def _page_floor(value: Int) -> Int:
    return (value // PAGE_BYTES) * PAGE_BYTES


def _page_ceil(value: Int) -> Int:
    return ((value + PAGE_BYTES - 1) // PAGE_BYTES) * PAGE_BYTES


struct StreamAccounting(Copyable, ImplicitlyCopyable):
    """Measured outcome of one pass over a mapped region.

    bytes_streamed counts payload bytes the pass actually touched;
    bytes_dropped counts bytes handed back with MADV_DONTNEED (always
    page-rounded inward, so it never overstates). Resident figures are
    OS numbers sampled during/after the pass (see file header).
    """

    var region_bytes: Int
    var window_bytes: Int
    var bytes_streamed: Int
    var windows: Int
    var bytes_dropped: Int
    var checksum: UInt64
    var peak_rss_bytes: Int
    var final_rss_bytes: Int
    var peak_mapping_resident_bytes: Int
    var final_mapping_resident_bytes: Int

    def __init__(
        out self,
        region_bytes: Int,
        window_bytes: Int,
        bytes_streamed: Int,
        windows: Int,
        bytes_dropped: Int,
        checksum: UInt64,
        peak_rss_bytes: Int,
        final_rss_bytes: Int,
        peak_mapping_resident_bytes: Int,
        final_mapping_resident_bytes: Int,
    ):
        self.region_bytes = region_bytes
        self.window_bytes = window_bytes
        self.bytes_streamed = bytes_streamed
        self.windows = windows
        self.bytes_dropped = bytes_dropped
        self.checksum = checksum
        self.peak_rss_bytes = peak_rss_bytes
        self.final_rss_bytes = final_rss_bytes
        self.peak_mapping_resident_bytes = peak_mapping_resident_bytes
        self.final_mapping_resident_bytes = final_mapping_resident_bytes

    def fully_streamed(self) -> Bool:
        """True iff the pass touched every byte of the region."""
        return self.bytes_streamed == self.region_bytes and self.windows > 0

    def dropped_coverage_bp(self) -> Int:
        """Dropped bytes as basis points of the region (10000 = all)."""
        if self.region_bytes <= 0:
            return 0
        return self.bytes_dropped * 10000 // self.region_bytes


struct OversizedStreaming:
    """Static gateway for windowed streaming over an mmap (A-049)."""

    @staticmethod
    def window_count(region_bytes: Int, window_bytes: Int) raises -> Int:
        if region_bytes < 0:
            raise Error("OversizedStreaming: negative region size")
        if window_bytes <= 0:
            raise Error("OversizedStreaming: window must be positive")
        if region_bytes == 0:
            return 0
        return (region_bytes + window_bytes - 1) // window_bytes

    @staticmethod
    def checksum_range(
        base: Pointer[UInt8, MutUntrackedOrigin], offset: Int, length: Int
    ) raises -> UInt64:
        """Word-wise FNV-1a over [offset, offset+length).

        The read is the touch: on an mmap this faults exactly these
        pages in. Word-at-a-time keeps a 40 GiB sweep at memory speed;
        the head (< 8 bytes, to word alignment) and the tail (< 8
        bytes) are folded byte-wise.
        """
        if offset < 0 or length < 0:
            raise Error("OversizedStreaming.checksum_range: negative range")
        var hash = _FNV_OFFSET
        var index = 0
        var address = Int(base) + offset
        while index < length and (address + index) % 8 != 0:
            hash = (hash ^ UInt64(base.unsafe_offset(offset + index).unsafe_load())) * _FNV_PRIME
            index += 1
        while index + 8 <= length:
            var word = base.unsafe_offset(offset + index).unsafe_bitcast[UInt64]().unsafe_load()
            hash = (hash ^ word) * _FNV_PRIME
            index += 8
        while index < length:
            hash = (hash ^ UInt64(base.unsafe_offset(offset + index).unsafe_load())) * _FNV_PRIME
            index += 1
        return hash

    @staticmethod
    def _madvise_range(
        base: Pointer[UInt8, MutUntrackedOrigin],
        offset: Int,
        length: Int,
        advice: Int,
    ) raises:
        """madvise() over [offset, offset+length) of the mapping.

        Fail-closed (house style): a failed madvise raises, because
        the streaming claim rests on the drop actually happening.
        """
        if length <= 0:
            return
        var rc = external_call["madvise", Int32](
            base.unsafe_offset(offset), UInt64(length), Int32(advice)
        )
        if rc != 0:
            raise Error("OversizedStreaming: madvise failed")

    @staticmethod
    def drop_region(
        base: Pointer[UInt8, MutUntrackedOrigin], offset: Int, length: Int
    ) raises -> Int:
        """MADV_DONTNEED the page-rounded-inward span of a region.

        Returns the bytes actually handed back (never more than the
        region: the first and last partial pages are kept).
        """
        if offset < 0 or length < 0:
            raise Error("OversizedStreaming.drop_region: negative range")
        var start = _page_ceil(offset)
        var end = _page_floor(offset + length)
        if end <= start:
            return 0
        Self._madvise_range(base, start, end - start, MADV_DONTNEED)
        return end - start

    @staticmethod
    def _sample(
        base: Pointer[UInt8, MutUntrackedOrigin],
        mut peak_rss: Int,
        mut peak_mapping: Int,
    ) raises:
        var rss = WeightResidency.process_rss_bytes()
        if rss > peak_rss:
            peak_rss = rss
        var mapping = WeightResidency.mapping_accounting(base)
        if mapping.resident_bytes > peak_mapping:
            peak_mapping = mapping.resident_bytes

    @staticmethod
    def sweep_region(
        base: Pointer[UInt8, MutUntrackedOrigin],
        region_offset: Int,
        region_bytes: Int,
        window_bytes: Int,
    ) raises -> StreamAccounting:
        """Sequential windowed pass with drop-behind (the streaming leg).

        Each window is checksummed (faulted in), sampled, then handed
        back with MADV_DONTNEED; the next window is prefetched with
        MADV_WILLNEED while the current one is consumed. Resident
        bytes therefore stay bounded by the window plus whatever
        readahead the kernel chooses, independent of region size.
        """
        if region_offset < 0:
            raise Error("OversizedStreaming.sweep_region: negative offset")
        var windows = Self.window_count(region_bytes, window_bytes)
        var checksum: UInt64 = _FNV_OFFSET
        var bytes_streamed = 0
        var bytes_dropped = 0
        var peak_rss = 0
        var peak_mapping = 0
        Self._sample(base, peak_rss, peak_mapping)
        for window in range(windows):
            var woff = window * window_bytes
            var wlen = window_bytes
            if woff + wlen > region_bytes:
                wlen = region_bytes - woff
            if window + 1 < windows:
                var noff = (window + 1) * window_bytes
                var nlen = window_bytes
                if noff + nlen > region_bytes:
                    nlen = region_bytes - noff
                # madvise requires a page-aligned start (EINVAL
                # otherwise -- the A-049 pad region starts at file
                # offset 611168). Prefetch is advisory, so round the
                # range OUTWARD to page boundaries; the drop path
                # (drop_region) rounds inward instead, so handed-back
                # bytes are never overstated.
                var nstart = _page_floor(region_offset + noff)
                var nend = _page_ceil(region_offset + noff + nlen)
                Self._madvise_range(base, nstart, nend - nstart, MADV_WILLNEED)
            var window_checksum = Self.checksum_range(base, region_offset + woff, wlen)
            checksum = (checksum * _FNV_PRIME) ^ window_checksum
            bytes_streamed += wlen
            Self._sample(base, peak_rss, peak_mapping)
            bytes_dropped += Self.drop_region(base, region_offset + woff, wlen)
        var final_rss = WeightResidency.process_rss_bytes()
        var final_mapping = WeightResidency.mapping_accounting(base)
        return StreamAccounting(
            region_bytes,
            window_bytes,
            bytes_streamed,
            windows,
            bytes_dropped,
            checksum,
            peak_rss,
            final_rss,
            peak_mapping,
            final_mapping.resident_bytes,
        )

    @staticmethod
    def touch_region(
        base: Pointer[UInt8, MutUntrackedOrigin],
        region_offset: Int,
        region_bytes: Int,
        window_bytes: Int,
    ) raises -> StreamAccounting:
        """Control pass: the identical sequential checksum, no madvise.

        Pages faulted in stay resident, so on a region the host can
        hold, the mapping's resident bytes grow to the region size --
        the full-residency behaviour the sweep exists to avoid.
        bytes_dropped is zero by construction.
        """
        if region_offset < 0:
            raise Error("OversizedStreaming.touch_region: negative offset")
        var windows = Self.window_count(region_bytes, window_bytes)
        var checksum: UInt64 = _FNV_OFFSET
        var bytes_streamed = 0
        var peak_rss = 0
        var peak_mapping = 0
        Self._sample(base, peak_rss, peak_mapping)
        for window in range(windows):
            var woff = window * window_bytes
            var wlen = window_bytes
            if woff + wlen > region_bytes:
                wlen = region_bytes - woff
            var window_checksum = Self.checksum_range(base, region_offset + woff, wlen)
            checksum = (checksum * _FNV_PRIME) ^ window_checksum
            bytes_streamed += wlen
            Self._sample(base, peak_rss, peak_mapping)
        var final_rss = WeightResidency.process_rss_bytes()
        var final_mapping = WeightResidency.mapping_accounting(base)
        return StreamAccounting(
            region_bytes,
            window_bytes,
            bytes_streamed,
            windows,
            0,
            checksum,
            peak_rss,
            final_rss,
            peak_mapping,
            final_mapping.resident_bytes,
        )
