# core/hip_transfer.mojo
# HipTransfer / HipStream / HipEvent: HIP transfers and streams for the
# AMD ROCm / HIP realm (slice A-012, building on A-011 HipMemory).
#
# Real hipMemcpy (sync, incl. device-to-device), hipMemcpyAsync,
# hipStreamCreateWithFlags / hipStreamSynchronize / hipStreamQuery /
# hipStreamDestroy, hipHostMalloc / hipHostFree (pinned host memory) and
# hipEvent* timing, reached through the flat C ABI in
# aesir_engine/hip_memory_shim.c (libaesir_hip.so; the A-011 shim,
# extended for this slice - dynamic loading lives in C because Mojo 1.0
# cannot mix this repo's external_call dlopen idiom with stdlib
# OwnedDLHandle in one program).
#
# Stream semantics proven on purpleraider before this wrapper was
# written (hidden_files/a012_c_probe.log): hipStreamQuery returns 0
# (hipSuccess) once the stream is drained and 600 (hipErrorNotReady)
# while work is in flight; streams are created with
# hipStreamNonBlocking so distinct streams do not implicitly
# synchronise with the legacy default stream.
#
# Overlap honesty (A-012 probe, filed in the ledger): on Strix Halo's
# unified-memory pool, concurrent streams were byte-exact but NOT
# faster than one stream for the probed sizes - transfers appear
# memory-pool bound. The multi-stream battery in the tests therefore
# asserts concurrent-stream CORRECTNESS (enqueue all, then sync all,
# byte-exact) and files both timings; it never asserts a speedup.
#
# Fail-closed contract: when the HIP runtime or the transfer symbols
# are not loadable, every operation raises; a zero or destroyed stream
# or event handle is rejected locally before any FFI call. Stream and
# event handles are owned by the caller and must be destroyed exactly
# once; pinned host allocations must be released with
# HipTransfer.host_free() exactly once.

from std.ffi import external_call
from std.memory import Pointer
from core.checked_span import checked_span

comptime _HIP_MEMCPY_HOST_TO_DEVICE = 1
comptime _HIP_MEMCPY_DEVICE_TO_HOST = 2
comptime _HIP_MEMCPY_DEVICE_TO_DEVICE = 3
comptime _HIP_ERROR_NOT_READY = 600
comptime _HIP_ABSENT = -1


def _raise_for_rc(what: String, rc: Int32) raises:
    if Int(rc) == _HIP_ABSENT:
        raise Error(
            "HipTransfer." + what + ": HIP runtime / transfer symbols are"
            " not loadable on this host (honest-absent)"
        )
    raise Error(
        "HipTransfer." + what + ": HIP call failed, code " + String(Int(rc))
    )


struct HipTransfer:
    """Static HIP transfer gateway (A-012). See file header."""

    @staticmethod
    def transfer_available() -> Bool:
        """True iff the shim loaded libamdhip64 and resolved every
        A-011 memory entry point AND every A-012 transfer entry point
        (streams, async memcpy, pinned host memory, events)."""
        return external_call["aesir_hip_transfer_available", Int32]() == Int32(1)

    @staticmethod
    def host_allocate(
        size_bytes: Int,
    ) raises -> Pointer[UInt8, MutUntrackedOrigin]:
        """hipHostMalloc: pinned (page-locked) host memory. Async
        copies to/from pinned memory are genuinely asynchronous;
        pageable host memory may be staged by the runtime."""
        if size_bytes <= 0:
            raise Error("HipTransfer.host_allocate: size_bytes must be positive")
        var addr: Int = 0
        var rc = external_call["aesir_hip_host_malloc", Int32](
            Pointer(to=addr), UInt64(size_bytes)
        )
        if rc != 0:
            _raise_for_rc("host_allocate", rc)
        if addr == 0:
            raise Error("HipTransfer.host_allocate: hipHostMalloc returned null")
        return Pointer[UInt8, MutUntrackedOrigin](unsafe_from_address=addr)

    @staticmethod
    def host_free(ptr: Pointer[UInt8, MutUntrackedOrigin]) raises:
        """hipHostFree for a HipTransfer.host_allocate pointer. Null is
        a no-op (house style); any other pointer must be a live pinned
        allocation, freed exactly once."""
        if Int(ptr) == 0:
            return
        var rc = external_call["aesir_hip_host_free", Int32](ptr)
        if rc != 0:
            _raise_for_rc("host_free", rc)

    @staticmethod
    def memcpy_device_to_device(
        dst_dev: Pointer[UInt8, MutUntrackedOrigin],
        src_dev: Pointer[UInt8, MutUntrackedOrigin],
        size_bytes: Int,
    ) raises:
        """Synchronous hipMemcpy device->device, size in BYTES. The
        byte count is admitted through checked_span discipline."""
        var span = checked_span(0, size_bytes, size_bytes)
        if span.length == 0:
            return
        var rc = external_call["aesir_hip_memcpy", Int32](
            dst_dev, src_dev, UInt64(span.length),
            Int32(_HIP_MEMCPY_DEVICE_TO_DEVICE),
        )
        if rc != 0:
            _raise_for_rc("memcpy_device_to_device", rc)


struct HipStream(Copyable, ImplicitlyCopyable):
    """An owned HIP stream handle (A-012). Create with HipStream.create(),
    destroy exactly once with destroy(); a destroyed stream rejects
    every further operation locally."""

    var handle: Int

    def __init__(out self, handle: Int):
        self.handle = handle

    @staticmethod
    def create() raises -> HipStream:
        """hipStreamCreateWithFlags(hipStreamNonBlocking)."""
        var addr: Int = 0
        var rc = external_call["aesir_hip_stream_create", Int32](
            Pointer(to=addr)
        )
        if rc != 0:
            _raise_for_rc("stream_create", rc)
        if addr == 0:
            raise Error("HipStream.create: HIP returned a null stream handle")
        return HipStream(addr)

    def _require_live(self, what: String) raises:
        if self.handle == 0:
            raise Error(
                "HipStream." + what + ": stream handle is zero or already"
                " destroyed"
            )

    def destroy(mut self) raises:
        """hipStreamDestroy. The handle is zeroed first so a second
        destroy (or any later use) is rejected locally, never passed
        to HIP as a dangling handle."""
        self._require_live("destroy")
        var handle = self.handle
        self.handle = 0
        var rc = external_call["aesir_hip_stream_destroy", Int32](
            UInt64(handle)
        )
        if rc != 0:
            _raise_for_rc("stream_destroy", rc)

    def synchronize(self) raises:
        """hipStreamSynchronize: block until this stream's work drains."""
        self._require_live("synchronize")
        var rc = external_call["aesir_hip_stream_synchronize", Int32](
            UInt64(self.handle)
        )
        if rc != 0:
            _raise_for_rc("stream_synchronize", rc)

    def query_complete(self) raises -> Bool:
        """hipStreamQuery: True once the stream has drained, False
        while work is in flight (HIP code 600, hipErrorNotReady)."""
        self._require_live("query_complete")
        var rc = external_call["aesir_hip_stream_query", Int32](
            UInt64(self.handle)
        )
        if Int(rc) == 0:
            return True
        if Int(rc) == _HIP_ERROR_NOT_READY:
            return False
        _raise_for_rc("stream_query", rc)
        return False

    def memcpy_async_host_to_device(
        self,
        dst_dev: Pointer[UInt8, MutUntrackedOrigin],
        src_host: Pointer[UInt8, MutUntrackedOrigin],
        size_bytes: Int,
    ) raises:
        """hipMemcpyAsync host->device on this stream, size in BYTES."""
        self._require_live("memcpy_async_host_to_device")
        var span = checked_span(0, size_bytes, size_bytes)
        if span.length == 0:
            return
        var rc = external_call["aesir_hip_memcpy_async", Int32](
            dst_dev, src_host, UInt64(span.length),
            Int32(_HIP_MEMCPY_HOST_TO_DEVICE), UInt64(self.handle),
        )
        if rc != 0:
            _raise_for_rc("memcpy_async_host_to_device", rc)

    def memcpy_async_device_to_host(
        self,
        dst_host: Pointer[UInt8, MutUntrackedOrigin],
        src_dev: Pointer[UInt8, MutUntrackedOrigin],
        size_bytes: Int,
    ) raises:
        """hipMemcpyAsync device->host on this stream, size in BYTES."""
        self._require_live("memcpy_async_device_to_host")
        var span = checked_span(0, size_bytes, size_bytes)
        if span.length == 0:
            return
        var rc = external_call["aesir_hip_memcpy_async", Int32](
            dst_host, src_dev, UInt64(span.length),
            Int32(_HIP_MEMCPY_DEVICE_TO_HOST), UInt64(self.handle),
        )
        if rc != 0:
            _raise_for_rc("memcpy_async_device_to_host", rc)

    def memcpy_async_device_to_device(
        self,
        dst_dev: Pointer[UInt8, MutUntrackedOrigin],
        src_dev: Pointer[UInt8, MutUntrackedOrigin],
        size_bytes: Int,
    ) raises:
        """hipMemcpyAsync device->device on this stream, size in BYTES."""
        self._require_live("memcpy_async_device_to_device")
        var span = checked_span(0, size_bytes, size_bytes)
        if span.length == 0:
            return
        var rc = external_call["aesir_hip_memcpy_async", Int32](
            dst_dev, src_dev, UInt64(span.length),
            Int32(_HIP_MEMCPY_DEVICE_TO_DEVICE), UInt64(self.handle),
        )
        if rc != 0:
            _raise_for_rc("memcpy_async_device_to_device", rc)


struct HipEvent(Copyable, ImplicitlyCopyable):
    """An owned HIP event handle (A-012) for device-side timing:
    record a start and a stop event on a stream, synchronise the stop
    event, and read the elapsed milliseconds between them."""

    var handle: Int

    def __init__(out self, handle: Int):
        self.handle = handle

    @staticmethod
    def create() raises -> HipEvent:
        """hipEventCreate (default flags: timing enabled)."""
        var addr: Int = 0
        var rc = external_call["aesir_hip_event_create", Int32](
            Pointer(to=addr)
        )
        if rc != 0:
            _raise_for_rc("event_create", rc)
        if addr == 0:
            raise Error("HipEvent.create: HIP returned a null event handle")
        return HipEvent(addr)

    def _require_live(self, what: String) raises:
        if self.handle == 0:
            raise Error(
                "HipEvent." + what + ": event handle is zero or already"
                " destroyed"
            )

    def destroy(mut self) raises:
        """hipEventDestroy; the handle is zeroed first (see HipStream)."""
        self._require_live("destroy")
        var handle = self.handle
        self.handle = 0
        var rc = external_call["aesir_hip_event_destroy", Int32](
            UInt64(handle)
        )
        if rc != 0:
            _raise_for_rc("event_destroy", rc)

    def record(self, stream: HipStream) raises:
        """hipEventRecord on the given (live) stream."""
        self._require_live("record")
        stream._require_live("record")
        var rc = external_call["aesir_hip_event_record", Int32](
            UInt64(self.handle), UInt64(stream.handle)
        )
        if rc != 0:
            _raise_for_rc("event_record", rc)

    def synchronize(self) raises:
        """hipEventSynchronize: block until this event completes."""
        self._require_live("synchronize")
        var rc = external_call["aesir_hip_event_synchronize", Int32](
            UInt64(self.handle)
        )
        if rc != 0:
            _raise_for_rc("event_synchronize", rc)

    def elapsed_ms(self, end: HipEvent) raises -> Float32:
        """hipEventElapsedTime from this (start) event to `end`, in
        milliseconds, as measured on the device. Both events must have
        been recorded and the end event must have completed."""
        self._require_live("elapsed_ms")
        end._require_live("elapsed_ms")
        var ms: Float32 = 0.0
        var rc = external_call["aesir_hip_event_elapsed_ms", Int32](
            UInt64(self.handle), UInt64(end.handle), Pointer(to=ms)
        )
        if rc != 0:
            _raise_for_rc("event_elapsed_ms", rc)
        return ms
