# core/structured_errors.mojo
# A-033: Structured errors everywhere.
# Every backend failure path maps to the repo ERROR_TAXONOMY.md.
# This module is the single mapping authority for backend failures:
# a backend kind-of-failure -> taxonomy code + name + severity, a
# StructuredError value whose render() is the raised Error text, a
# fault-injection entry point (inject_backend_failure) used by the
# A-033 tests per backend, and translation helpers that preserve an
# already-coded error or wrap a bare one as INT-002.
# Taxonomy reuse precedent (A-013, vulkan_context.mojo): the GPU
# category entries are named for CUDA in the taxonomy but are the
# GPU-category init / not-found / launch entries for every GPU-class
# backend (HIP, Vulkan, CUDA, NPU-via-XRT). Execution paths that are
# not implemented have no dedicated taxonomy code; they map to
# GPU-002 (no physical execution path present on this backend) for
# accelerator backends and MDL-010 (unsupported) on the CPU path.
# That taxonomy gap is recorded for the A-089 extension slice.
# Backends: cpu, hip, vulkan, npu, cuda (plus metal/intel/max gates
# reuse the accelerator mapping through their own prefixes).

comptime FAIL_UNAVAILABLE = 0
comptime FAIL_INIT = 1
comptime FAIL_ALLOC = 2
comptime FAIL_INVALID = 3
comptime FAIL_SHAPE = 4
comptime FAIL_LAUNCH = 5
comptime FAIL_SYNC = 6
comptime FAIL_UNSUPPORTED = 7
comptime FAIL_TRANSFER = 8
comptime FAIL_INTERNAL = 9


def taxonomy_name_for_structured_code(code: String) -> String:
    if code == "VAL-003":
        return String("VALUE_OUT_OF_RANGE")
    if code == "MEM-001":
        return String("HOST_MALLOC_FAILED")
    if code == "MEM-002":
        return String("DEVICE_ALLOC_FAILED")
    if code == "MEM-003":
        return String("OUT_OF_MEMORY")
    if code == "GPU-001":
        return String("CUDA_INIT_FAILED")
    if code == "GPU-002":
        return String("DEVICE_NOT_FOUND")
    if code == "GPU-003":
        return String("KERNEL_LAUNCH_FAILED")
    if code == "GPU-004":
        return String("DEVICE_SYNCHRONIZE_TIMEOUT")
    if code == "GPU-005":
        return String("ILLEGAL_MEMORY_ACCESS")
    if code == "GPU-006":
        return String("DRIVER_VERSION_MISMATCH")
    if code == "GPU-012":
        return String("ROCM_INIT_FAILED")
    if code == "INF-001":
        return String("FORWARD_PASS_EXCEPTION")
    if code == "INF-008":
        return String("KERNEL_LAUNCH_TIMEOUT")
    if code == "MDL-010":
        return String("QUANTIZATION_UNSUPPORTED")
    if code == "INT-001":
        return String("INVARIANT_VIOLATED")
    if code == "INT-002":
        return String("UNEXPECTED_NONE")
    if code == "INT-004":
        return String("MODULE_INITIALIZATION_ORDER")
    return String("UNKNOWN_TAXONOMY_CODE")


def severity_for_structured_code(code: String) -> String:
    if code == "VAL-003" or code == "MDL-010":
        return String("ERROR")
    if code == "GPU-002" or code == "INT-002":
        return String("ERROR")
    return String("CRITICAL")


def is_known_taxonomy_code(code: String) -> Bool:
    return taxonomy_name_for_structured_code(code) != "UNKNOWN_TAXONOMY_CODE"


def backend_error_code(backend: String, kind: Int) -> String:
    var accel = backend != "cpu"
    if kind == FAIL_UNAVAILABLE:
        if not accel:
            return String("INT-002")
        return String("GPU-002")
    if kind == FAIL_INIT:
        if backend == "hip":
            return String("GPU-012")
        if not accel:
            return String("INT-004")
        return String("GPU-001")
    if kind == FAIL_ALLOC:
        if not accel:
            return String("MEM-001")
        return String("MEM-002")
    if kind == FAIL_INVALID:
        return String("VAL-003")
    if kind == FAIL_SHAPE:
        return String("VAL-003")
    if kind == FAIL_LAUNCH:
        if not accel:
            return String("INF-001")
        return String("GPU-003")
    if kind == FAIL_SYNC:
        if not accel:
            return String("INF-008")
        return String("GPU-004")
    if kind == FAIL_UNSUPPORTED:
        if not accel:
            return String("MDL-010")
        return String("GPU-002")
    if kind == FAIL_TRANSFER:
        if not accel:
            return String("VAL-003")
        return String("GPU-004")
    return String("INT-001")


struct StructuredError(Copyable, ImplicitlyCopyable):
    var code: String
    var name: String
    var severity: String
    var backend: String
    var operation: String
    var detail: String

    def __init__(out self, code: String, backend: String, operation: String, detail: String):
        self.code = code
        self.name = taxonomy_name_for_structured_code(code)
        self.severity = severity_for_structured_code(code)
        self.backend = backend
        self.operation = operation
        self.detail = detail

    def render(self) -> String:
        return (
            self.code + " " + self.name + " [backend=" + self.backend
            + " op=" + self.operation + " severity=" + self.severity
            + "] " + self.detail
        )


def backend_failure(backend: String, kind: Int, operation: String, detail: String) -> StructuredError:
    return StructuredError(backend_error_code(backend, kind), backend, operation, detail)


def raise_backend_failure(backend: String, kind: Int, operation: String, detail: String) raises:
    raise Error(backend_failure(backend, kind, operation, detail).render())


def inject_backend_failure(backend: String, kind: Int) raises:
    raise_backend_failure(backend, kind, "fault_injection", "injected backend failure for A-033 taxonomy proof")


def structured_code_of(text: String) -> String:
    var codes = ["GPU-012", "GPU-001", "GPU-002", "GPU-003", "GPU-004", "GPU-005", "GPU-006", "MEM-001", "MEM-002", "MEM-003", "VAL-003", "INF-001", "INF-008", "MDL-010", "INT-001", "INT-002", "INT-004"]
    for i in range(len(codes)):
        if codes[i] in text:
            return codes[i]
    return String("")


def error_text_is_structured(text: String) -> Bool:
    return structured_code_of(text) != ""


def translate_backend_error(backend: String, operation: String, raw: String) -> StructuredError:
    var existing = structured_code_of(raw)
    if existing != "":
        return StructuredError(existing, backend, operation, raw)
    return StructuredError("INT-002", backend, operation, raw)


def coded_error_text(code: String, original: String) -> String:
    return code + " " + taxonomy_name_for_structured_code(code) + ": " + original
