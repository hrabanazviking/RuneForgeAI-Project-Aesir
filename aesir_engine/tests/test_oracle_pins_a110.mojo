# tests/test_oracle_pins_a110.mojo
# A-110: Oracle pin registry -- the filed registry is fully
# pinned wherever a row is judged, the in-repo registry file
# mirrors the filed rows, and mark_judged refuses any row
# with a missing or malformed pin (the roadmap acceptance).

from core.oracle_pins import (
    ORACLE_BACKEND_CPU_TF,
    OraclePinRow,
    is_build_hash,
    is_sha256_hex,
    mark_judged,
    missing_pins,
    oracle_pin_registry_summary,
    pins_complete,
    registry_rows,
)


def _pinned_row() -> OraclePinRow:
    return OraclePinRow(
        "TEST-ROW",
        "7b064f5842bf9532c91456deda288a1b672397a54fa729aa665952863033557c",
        ORACLE_BACKEND_CPU_TF,
        "7c1e7bd5286f143bb1ca5193a28f1eae3efa541b87f15bce7f291101706ac87c",
        "8d28067405893cce8c8bce168b08e002bd8a6f34d35729a5c2b63813b8171ce6",
        False,
    )


def _registry_text() raises -> String:
    try:
        with open("oracle_pin_registry.json", "r") as f:
            return f.read()
    except:
        with open("aesir_engine/../oracle_pin_registry.json", "r") as f:
            return f.read()


def test_pin_registry_judged_rows_pinned() raises:
    var rows = registry_rows()
    if len(rows) != 3:
        raise Error("registry row count drifted: " + String(len(rows)))
    var judged = 0
    for row in rows:
        if row.judged:
            judged += 1
            if not pins_complete(row):
                raise Error("judged row without complete pins: " + row.row_id)
    if judged != 1:
        raise Error("expected exactly 1 judged filed row, got " + String(judged))


def test_pin_registry_unpinned_example_unjudged() raises:
    var rows = registry_rows()
    var found = False
    for row in rows:
        if row.row_id == "A110-UNPINNED-EXAMPLE":
            found = True
            if row.judged:
                raise Error("unpinned example row is marked judged")
            if len(missing_pins(row)) != 4:
                raise Error("unpinned example must miss all four pins")
    if not found:
        raise Error("unpinned example row missing from registry")


def test_pin_missing_each_blocks() raises:
    var base = _pinned_row()
    var no_model = OraclePinRow(base.row_id, "", base.oracle_backend, base.oracle_build_hash, base.prompt_hash, False)
    var no_backend = OraclePinRow(base.row_id, base.model_sha256, "", base.oracle_build_hash, base.prompt_hash, False)
    var no_build = OraclePinRow(base.row_id, base.model_sha256, base.oracle_backend, "", base.prompt_hash, False)
    var no_prompt = OraclePinRow(base.row_id, base.model_sha256, base.oracle_backend, base.oracle_build_hash, "", False)
    var variants = List[OraclePinRow]()
    variants.append(no_model)
    variants.append(no_backend)
    variants.append(no_build)
    variants.append(no_prompt)
    var names = List[String]()
    names.append("model_sha256")
    names.append("oracle_backend")
    names.append("oracle_build_hash")
    names.append("prompt_hash")
    for i in range(len(variants)):
        var missing = missing_pins(variants[i])
        if len(missing) != 1 or missing[0] != names[i]:
            raise Error("blanked pin not named exactly: " + names[i])
        var refused = False
        try:
            _ = mark_judged(variants[i])
        except:
            refused = True
        if not refused:
            raise Error("mark_judged accepted a row missing " + names[i])


def test_pin_malformed_hash_blocks() raises:
    var base = _pinned_row()
    var short = OraclePinRow(base.row_id, "7b064f58", base.oracle_backend, base.oracle_build_hash, base.prompt_hash, False)
    if pins_complete(short):
        raise Error("short model sha accepted as a pin")
    var nonhex_prompt = OraclePinRow(base.row_id, base.model_sha256, base.oracle_backend, base.oracle_build_hash, "zz28067405893cce8c8bce168b08e002bd8a6f34d35729a5c2b63813b8171ce6", False)
    if pins_complete(nonhex_prompt):
        raise Error("non-hex prompt hash accepted as a pin")
    var upper = OraclePinRow(base.row_id, "7B064F5842BF9532C91456DEDA288A1B672397A54FA729AA665952863033557C", base.oracle_backend, base.oracle_build_hash, base.prompt_hash, False)
    if pins_complete(upper):
        raise Error("uppercase model sha accepted as a pin")


def test_pin_mark_judged_success() raises:
    var row = _pinned_row()
    if row.judged:
        raise Error("fixture row starts judged")
    var judged = mark_judged(row)
    if not judged.judged:
        raise Error("mark_judged did not set judged on a pinned row")
    if judged.model_sha256 != row.model_sha256 or judged.prompt_hash != row.prompt_hash:
        raise Error("mark_judged mutated the pins")


def test_pin_build_hash_forms() raises:
    if not is_build_hash("24d9f13c2aac2b95f2e35b7ee0d281cc111c198d"):
        raise Error("40-hex commit id rejected as build hash")
    if not is_build_hash("7c1e7bd5286f143bb1ca5193a28f1eae3efa541b87f15bce7f291101706ac87c"):
        raise Error("64-hex source sha rejected as build hash")
    if is_build_hash(""):
        raise Error("empty build hash accepted")
    if is_build_hash("24d9f13c"):
        raise Error("short build hash accepted")
    if not is_sha256_hex("8d28067405893cce8c8bce168b08e002bd8a6f34d35729a5c2b63813b8171ce6"):
        raise Error("real prompt hash rejected")


def test_pin_registry_file_in_repo() raises:
    var text = _registry_text()
    var needles = List[String]()
    needles.append("A045-PARITY-8B")
    needles.append("A110-PREREG-SEER")
    needles.append("A110-UNPINNED-EXAMPLE")
    needles.append("model_sha256")
    needles.append("oracle_backend")
    needles.append("oracle_build_hash")
    needles.append("prompt_hash")
    needles.append("7b064f5842bf9532c91456deda288a1b672397a54fa729aa665952863033557c")
    for i in range(len(needles)):
        if needles[i] not in text:
            raise Error("registry file missing: " + needles[i])
    if "cannot be marked judged" not in oracle_pin_registry_summary():
        raise Error("registry summary lost the acceptance rule")
