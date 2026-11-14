# core/oracle_pins.mojo
# A-110: Oracle pin registry -- every correctness-matrix row
# carries four pins before it may be marked judged:
#   model_sha256     sha256 of the exact model file graded
#   oracle_backend   which oracle graded the row (the Z13
#                    reference oracle is CPU teacher-forcing on
#                    RAW prompts, per the A-054 declaration;
#                    CPU engine vs CPU comparator only)
#   oracle_build_hash  hash identifying the oracle build that
#                    produced the grades (sha256 of the grading
#                    core source, or a 40-hex commit id)
#   prompt_hash      sha256 of the RAW prompt bytes (never a
#                    template-rendered prompt -- a rendered
#                    prompt is a comparator artifact, not an
#                    input)
#
# ACCEPTANCE (roadmap A-110): registry file in-repo
# (oracle_pin_registry.json at the repository root, mirrored
# by registry_rows() below) and a row without pins cannot be
# marked judged -- mark_judged() is the single enforcement
# point and raises, naming every missing or malformed pin.
# IQ rows are graded on rank + logit gap + coherence, never
# token-exactness; the near-tie band itself is A-111's gate
# rule, not this registry's business.

comptime PIN_MODEL_SHA256 = "model_sha256"
comptime PIN_ORACLE_BACKEND = "oracle_backend"
comptime PIN_ORACLE_BUILD_HASH = "oracle_build_hash"
comptime PIN_PROMPT_HASH = "prompt_hash"

comptime ORACLE_BACKEND_CPU_TF = "cpu-teacher-forcing"


def _is_lower_hex(byte: UInt8) -> Bool:
    return (byte >= 48 and byte <= 57) or (byte >= 97 and byte <= 102)


def is_sha256_hex(value: String) -> Bool:
    """True iff value is exactly 64 lowercase hex characters."""
    if value.byte_length() != 64:
        return False
    var bytes = value.as_bytes()
    for i in range(len(bytes)):
        if not _is_lower_hex(bytes[i]):
            return False
    return True


def is_build_hash(value: String) -> Bool:
    """True iff value is a plausible oracle build identifier:
    40 or 64 lowercase hex characters (commit id or sha256 of
    the oracle grading source)."""
    var n = value.byte_length()
    if n != 40 and n != 64:
        return False
    var bytes = value.as_bytes()
    for i in range(len(bytes)):
        if not _is_lower_hex(bytes[i]):
            return False
    return True


struct OraclePinRow(Copyable, ImplicitlyCopyable):
    var row_id: String
    var model_sha256: String
    var oracle_backend: String
    var oracle_build_hash: String
    var prompt_hash: String
    var judged: Bool

    def __init__(
        out self,
        row_id: String,
        model_sha256: String,
        oracle_backend: String,
        oracle_build_hash: String,
        prompt_hash: String,
        judged: Bool,
    ):
        self.row_id = row_id
        self.model_sha256 = model_sha256
        self.oracle_backend = oracle_backend
        self.oracle_build_hash = oracle_build_hash
        self.prompt_hash = prompt_hash
        self.judged = judged


def missing_pins(row: OraclePinRow) -> List[String]:
    """Names of the pins that are absent or malformed, in
    roadmap order. Empty list == the row is fully pinned."""
    var missing = List[String]()
    if not is_sha256_hex(row.model_sha256):
        missing.append(PIN_MODEL_SHA256)
    if row.oracle_backend.byte_length() == 0:
        missing.append(PIN_ORACLE_BACKEND)
    if not is_build_hash(row.oracle_build_hash):
        missing.append(PIN_ORACLE_BUILD_HASH)
    if not is_sha256_hex(row.prompt_hash):
        missing.append(PIN_PROMPT_HASH)
    return missing^


def pins_complete(row: OraclePinRow) -> Bool:
    return len(missing_pins(row)) == 0


def mark_judged(row: OraclePinRow) raises -> OraclePinRow:
    """The single enforcement point for the A-110 acceptance:
    a row without pins cannot be marked judged. Raises, naming
    every missing or malformed pin; on success returns a copy
    of the row with judged set."""
    var missing = missing_pins(row)
    if len(missing) > 0:
        var names = String("")
        for i in range(len(missing)):
            if i > 0:
                names += ", "
            names += missing[i]
        raise Error(
            "A-110: row " + row.row_id
            + " cannot be marked judged; missing/malformed pins: "
            + names
        )
    return OraclePinRow(
        row.row_id,
        row.model_sha256,
        row.oracle_backend,
        row.oracle_build_hash,
        row.prompt_hash,
        True,
    )


def registry_rows() -> List[OraclePinRow]:
    """The filed registry, mirroring oracle_pin_registry.json
    at the repository root (the in-repo registry file). The
    suite cross-checks the two so they cannot drift silently.
    Pins below were computed on purpleraider at filing time:
    the model sha256 is the A-049-class fixture pin (verified
    == the A-067/A-081 pin), the prompt hashes are sha256 of
    the RAW prompt bytes, and the build hash is the sha256 of
    aesir_engine/core/parity_battery.mojo (the rank + logit
    gap grading core) at the A-110 base."""
    var rows = List[OraclePinRow]()
    rows.append(OraclePinRow(
        "A045-PARITY-8B",
        "7b064f5842bf9532c91456deda288a1b672397a54fa729aa665952863033557c",
        ORACLE_BACKEND_CPU_TF,
        "7c1e7bd5286f143bb1ca5193a28f1eae3efa541b87f15bce7f291101706ac87c",
        "8d28067405893cce8c8bce168b08e002bd8a6f34d35729a5c2b63813b8171ce6",
        True,
    ))
    rows.append(OraclePinRow(
        "A110-PREREG-SEER",
        "7b064f5842bf9532c91456deda288a1b672397a54fa729aa665952863033557c",
        ORACLE_BACKEND_CPU_TF,
        "7c1e7bd5286f143bb1ca5193a28f1eae3efa541b87f15bce7f291101706ac87c",
        "7182c315c0af73fc2f7176203c1b73525716a3a1be2c6a9fff33561627773fe0",
        False,
    ))
    rows.append(OraclePinRow(
        "A110-UNPINNED-EXAMPLE",
        "",
        "",
        "",
        "",
        False,
    ))
    return rows^


def oracle_pin_registry_summary() -> String:
    return String(
        "A-110 oracle pin registry: every matrix row records"
        " model sha256, oracle backend, oracle build hash and"
        " prompt hash; a row without pins cannot be marked"
        " judged (mark_judged raises)"
    )
