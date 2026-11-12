"""A-053: state machinery verified on the Z13 checkout filesystem.

The pre-existing state batteries root their files in /tmp, which is a
tmpfs on this machine: fsync and rename there prove nothing about the
btrfs volume that actually holds Aesir state on the Z13. These cases
re-run the same invariants -- conversation autosave generations,
StateVault disk checkpoints, the durable model catalog, and checksummed
conversation snapshots -- against roots in the process working
directory (the checkout, on btrfs /home), and they assert in-case that
the state root's device differs from /tmp's device, so the proof
cannot silently fall back to tmpfs.
"""

from std.ffi import external_call
from std.collections import InlineArray
from cli.conversation import (
    ConversationState,
    load_conversation,
    save_conversation,
)
from cli.conversation_autosave import ConversationAutosave
from cli.storage import DurableModelStore
from core.state_vault import StateVault, _vault_read


def _z13_cstring(value: String) -> List[Int8]:
    var result = List[Int8]()
    for byte in value.as_bytes():
        result.append(Int8(byte))
    result.append(0)
    return result^


def _z13_exists(path: String) -> Bool:
    var encoded = _z13_cstring(path)
    return external_call["access", Int32](encoded.unsafe_ptr(), 0) == 0


def _z13_unlink(path: String):
    var encoded = _z13_cstring(path)
    _ = external_call["unlink", Int32](encoded.unsafe_ptr())


def _z13_device(path: String) raises -> UInt64:
    """Returns st_dev for a path, via an O_RDONLY open + fstat."""
    var encoded = _z13_cstring(path)
    var fd = external_call["open64", Int32](
        encoded.unsafe_ptr(), Int32(0), Int32(0)
    )
    if fd < 0:
        raise Error("unable to open path for device check: " + path)
    var stat = InlineArray[UInt64, 18](fill=0)
    if external_call["fstat", Int32](fd, stat.unsafe_ptr()) != 0:
        _ = external_call["close", Int32](fd)
        raise Error("unable to stat path for device check: " + path)
    var device = stat[0]
    _ = external_call["close", Int32](fd)
    return device


def _z13_require_checkout_filesystem(root: String) raises:
    """The state root must live on the checkout's device, not tmpfs."""
    if _z13_device(root) == _z13_device("/tmp"):
        raise Error("state root device equals /tmp device (tmpfs)")
    if _z13_device(root) != _z13_device("."):
        raise Error("state root device differs from the checkout device")


def _z13_state(turn_count: Int) raises -> ConversationState:
    var state = ConversationState(
        "sha256:z13-storage-fixture", "llama3", 64,
        "Remember.", "greedy; seed=42",
    )
    for index in range(turn_count):
        state.tokens.append(200 + index)
        state.append_turn(
            "user-" + String(index + 1), "assistant-" + String(index + 1)
        )
    state.sampler_draws = turn_count
    return state^


def _z13_checkpoint(root: String, turn_count: Int) raises:
    var autosave = ConversationAutosave(root, 2)
    autosave.checkpoint(_z13_state(turn_count), turn_count)


def _z13_begin(root: String, turn: Int) raises:
    var autosave = ConversationAutosave(root, 2)
    autosave.begin(turn)


def _z13_recover(root: String) raises -> Tuple[Int, Int, Int, Int]:
    var autosave = ConversationAutosave(root, 2)
    var state = autosave.load_latest()
    var first_token = 0
    var last_token = 0
    if len(state.tokens) > 0:
        first_token = state.tokens[0]
        last_token = state.tokens[len(state.tokens) - 1]
    return (
        len(state.turns), autosave.interrupted_generation(),
        autosave.interrupted_turn_number(), first_token * 1000 + last_token,
    )


def _z13_discard(root: String) raises:
    var autosave = ConversationAutosave(root, 2)
    autosave.discard_interrupted()


def test_storage_z13_autosave_generations() raises:
    var root = (
        ".aesir-test-z13-autosave-"
        + String(external_call["getpid", Int32]())
    )
    if _z13_exists(root):
        raise Error("refusing to reuse a pre-existing Z13 autosave root")
    var root_bytes = _z13_cstring(root)
    if external_call["mkdir", Int32](root_bytes.unsafe_ptr(), 448) != 0:
        raise Error("unable to create Z13 autosave test directory")
    try:
        _z13_require_checkout_filesystem(root)
        var sentinel = root + "/user-note.txt"
        var sentinel_bytes = _z13_cstring(sentinel)
        var sentinel_fd = external_call["open64", Int32](
            sentinel_bytes.unsafe_ptr(), Int32(193), Int32(384)
        )
        if sentinel_fd < 0 or external_call["close", Int32](sentinel_fd) != 0:
            raise Error("unable to create Z13 autosave sentinel")

        # Three checkpoints with retention 2, on the real filesystem.
        for turn_count in range(1, 4):
            _z13_checkpoint(root, turn_count)
        if (
            _z13_exists(root + "/generation-1.aesir")
            or not _z13_exists(root + "/generation-2.aesir")
            or not _z13_exists(root + "/generation-3.aesir")
            or not _z13_exists(sentinel)
        ):
            raise Error("Z13 autosave retention escaped its owned set")

        # A fresh owner (restart) recovers the latest committed state,
        # with exact token IDs (200, 201, 202 packed as 200202).
        var recovered = _z13_recover(root)
        if recovered[0] != 3 or recovered[1] != 0 or recovered[3] != 200202:
            raise Error("Z13 autosave did not recover the latest generation")

        # An interrupted begin is reported, then discarded cleanly.
        _z13_begin(root, 4)
        recovered = _z13_recover(root)
        if recovered[0] != 3 or recovered[1] != 4 or recovered[2] != 4:
            raise Error("Z13 autosave lost committed state across interruption")
        _z13_discard(root)
        if _z13_exists(root + "/inflight") or not _z13_exists(sentinel):
            raise Error("Z13 autosave cleanup touched an unowned file")
    except error:
        _z13_unlink(root + "/inflight")
        _z13_unlink(root + "/current")
        for generation in range(1, 5):
            _z13_unlink(
                root + "/generation-" + String(generation) + ".aesir"
            )
        _z13_unlink(root + "/user-note.txt")
        _ = external_call["rmdir", Int32](root_bytes.unsafe_ptr())
        raise error

    _z13_unlink(root + "/current")
    _z13_unlink(root + "/generation-2.aesir")
    _z13_unlink(root + "/generation-3.aesir")
    _z13_unlink(root + "/user-note.txt")
    if external_call["rmdir", Int32](root_bytes.unsafe_ptr()) != 0:
        raise Error("unable to remove Z13 autosave test directory")
    print("Z13 storage autosave generations on checkout filesystem: PASS")


def test_storage_z13_state_vault_disk() raises:
    var path = (
        ".aesir-test-z13-vault-"
        + String(external_call["getpid", Int32]()) + ".chk"
    )
    if _z13_exists(path):
        raise Error("refusing to reuse a pre-existing Z13 vault path")
    try:
        var vault = StateVault()
        var checkpoint = vault.save_checkpoint_to_disk(path, 384, 48, 7000)
        if checkpoint.token_pos != 384 or checkpoint.prompt_tokens_count != 48:
            raise Error("Z13 vault checkpoint fields changed on save")
        if _z13_device(path) == _z13_device("/tmp"):
            raise Error("Z13 vault checkpoint landed on the tmpfs device")
        var raw = _vault_read(path)
        if len(raw.bytes()) == 0:
            raise Error("Z13 vault checkpoint read back empty")

        # A fresh vault (restart) loads the exact on-disk marker.
        var loaded_vault = StateVault()
        var loaded = loaded_vault.load_checkpoint_from_disk(path)
        if (
            loaded.token_pos != 384
            or loaded.prompt_tokens_count != 48
            or loaded.checksum != checkpoint.checksum
            or loaded.timestamp != checkpoint.timestamp
        ):
            raise Error("Z13 vault checkpoint did not survive restart")

        # On-disk corruption is rejected and mutates no active state.
        var corrupt_file = open(path, "w")
        corrupt_file.write("TOKEN_POS=999\n")
        corrupt_file.close()
        var rejected = False
        try:
            _ = loaded_vault.load_checkpoint_from_disk(path)
        except:
            rejected = True
        if (
            not rejected
            or loaded_vault.active_checkpoint.token_pos != 384
            or loaded_vault.active_checkpoint.checksum != checkpoint.checksum
        ):
            raise Error("Z13 vault accepted on-disk corruption")
    except error:
        _z13_unlink(path)
        raise error
    _z13_unlink(path)
    print("Z13 storage StateVault disk checkpoint: PASS")


def test_storage_z13_catalog_restart() raises:
    var root = (
        ".aesir-test-z13-catalog-"
        + String(external_call["getpid", Int32]())
    )
    if _z13_exists(root):
        raise Error("refusing to reuse a pre-existing Z13 catalog root")
    var root_bytes = _z13_cstring(root)
    try:
        _z13_require_checkout_filesystem(".")
        var mf_text = String(
            "FROM test.gguf\nPARAMETER temperature 0.7\nSYSTEM You are test."
        )
        var store = DurableModelStore(root)
        store.create_model("z13store:v1", mf_text)
        var fetched = store.get_model("z13store:v1")
        if not _z13_exists(root + "/catalog.v1"):
            raise Error("Z13 catalog file missing after create_model")

        # A fresh store instance (restart) reads the catalog from disk.
        var restarted = DurableModelStore(root)
        var models = restarted.list_models()
        if len(models) != 1:
            raise Error("Z13 catalog did not survive restart")
        var restored = restarted.get_model("z13store:v1")
        if restored.name != "z13store" or restored.digest != fetched.digest:
            raise Error("Z13 catalog identity changed across restart")
    except error:
        _z13_unlink(root + "/catalog.v1")
        _ = external_call["rmdir", Int32](root_bytes.unsafe_ptr())
        raise error
    _z13_unlink(root + "/catalog.v1")
    if external_call["rmdir", Int32](root_bytes.unsafe_ptr()) != 0:
        raise Error("unable to remove Z13 catalog test directory")
    print("Z13 storage durable catalog restart: PASS")


def test_storage_z13_conversation_snapshot() raises:
    var path = (
        ".aesir-test-z13-conversation-"
        + String(external_call["getpid", Int32]()) + ".aesir"
    )
    if _z13_exists(path):
        raise Error("refusing to reuse a pre-existing Z13 snapshot path")
    try:
        var state = _z13_state(3)
        save_conversation(path, state)
        if _z13_device(path) == _z13_device("/tmp"):
            raise Error("Z13 conversation snapshot landed on tmpfs")

        # A fresh load recovers exact tokens and turns from disk.
        var loaded = load_conversation(path)
        if len(loaded.turns) != 3 or len(loaded.tokens) != 3:
            raise Error("Z13 conversation snapshot lost turns or tokens")
        if loaded.tokens[0] != 200 or loaded.tokens[2] != 202:
            raise Error("Z13 conversation snapshot token mismatch")
        if loaded.sampler_draws != 3:
            raise Error("Z13 conversation snapshot sampler position mismatch")

        # On-disk tampering is rejected by the record checksum.
        var tampered_file = open(path, "w")
        tampered_file.write("garbage\n")
        tampered_file.close()
        var rejected = False
        try:
            _ = load_conversation(path)
        except:
            rejected = True
        if not rejected:
            raise Error("Z13 conversation snapshot accepted tampered bytes")
    except error:
        _z13_unlink(path)
        raise error
    _z13_unlink(path)
    print("Z13 storage conversation snapshot: PASS")
