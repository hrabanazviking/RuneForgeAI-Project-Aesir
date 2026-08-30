# core/state_vault.mojo
# StateVault: Versioned Durable Checkpoint & Integrity Protection Engine

from std.memory import Pointer
from core.mimir_well import Scalar, f16

struct VaultCheckpoint(Copyable, ImplicitlyCopyable):
    """Integrity-protected atomic state checkpoint."""
    var token_pos: Int
    var prompt_tokens_count: Int
    var checksum: Int64
    var timestamp: Int64
    var is_valid: Bool

    def __init__(out self, token_pos: Int = 0, prompt_tokens_count: Int = 0, checksum: Int64 = 0, timestamp: Int64 = 0, is_valid: Bool = False):
        self.token_pos = token_pos
        self.prompt_tokens_count = prompt_tokens_count
        self.checksum = checksum
        self.timestamp = timestamp
        self.is_valid = is_valid

    def __copyinit__(out self, existing: Self):
        self.token_pos = existing.token_pos
        self.prompt_tokens_count = existing.prompt_tokens_count
        self.checksum = existing.checksum
        self.timestamp = existing.timestamp
        self.is_valid = existing.is_valid


struct StateVault(Copyable, ImplicitlyCopyable):
    """
    ᛋᛏᚨᛏᛖ·ᚠᚨᚢᛚᛏ — The Vault of Unbroken State (StateVault)
    ═════════════════════════════════════════════════════════
    Stores versioned, integrity-protected checkpoints with checksum verification
    and restoration guards against memory corruption.
    """
    var is_checkpointed: Bool
    var active_checkpoint: VaultCheckpoint

    def __init__(out self):
        self.is_checkpointed = False
        self.active_checkpoint = VaultCheckpoint()

    def __copyinit__(out self, existing: Self):
        self.is_checkpointed = existing.is_checkpointed
        self.active_checkpoint = existing.active_checkpoint.copy()

    def _compute_checksum(self, token_pos: Int, prompt_count: Int, ts: Int64) -> Int64:
        return Int64(token_pos * 31 + prompt_count * 17) + ts ^ Int64(0x5A5A5A5A)

    def save_checkpoint(mut self, token_pos: Int, prompt_count: Int, timestamp: Int64 = 1000) -> VaultCheckpoint:
        """
        Creates an atomic integrity-protected checkpoint with computed checksum.
        """
        if token_pos < 0 or prompt_count < 0:
            return VaultCheckpoint()
        var cs = self._compute_checksum(token_pos, prompt_count, timestamp)
        var chk = VaultCheckpoint(token_pos, prompt_count, cs, timestamp, True)
        self.active_checkpoint = chk
        self.is_checkpointed = True
        return chk

    def restore_checkpoint_checked(self, chk: VaultCheckpoint) raises -> Int:
        """
        Restores state after verifying checksum integrity.
        Raises Error on checksum mismatch or invalid checkpoint.
        """
        if not chk.is_valid:
            raise Error("StateVault invalid checkpoint marker")
        var expected_cs = self._compute_checksum(chk.token_pos, chk.prompt_tokens_count, chk.timestamp)
        if chk.checksum != expected_cs:
            raise Error("StateVault checksum corruption detected - integrity verification failed")
        return chk.token_pos

    def restore_checkpoint(self) -> Int:
        """
        Legacy unverified restore fallback.
        """
        if not self.is_checkpointed or not self.active_checkpoint.is_valid:
            return 0
        return self.active_checkpoint.token_pos

    def save_checkpoint_to_disk(
        mut self, file_path: String, token_pos: Int, prompt_count: Int, timestamp: Int64 = 1000
    ) raises -> VaultCheckpoint:
        """
        Saves an integrity-protected checkpoint directly to a disk file.
        """
        var chk = self.save_checkpoint(token_pos, prompt_count, timestamp)
        var opt_f = open(file_path, "w")
        var content = String("TOKEN_POS=") + String(chk.token_pos) + String("\nPROMPT_COUNT=") + String(chk.prompt_tokens_count) + String("\nCHECKSUM=") + String(chk.checksum) + String("\nTIMESTAMP=") + String(chk.timestamp) + String("\n")
        opt_f.write(content)
        opt_f.close()
        return chk

    def load_checkpoint_from_disk(mut self, file_path: String) raises -> VaultCheckpoint:
        """
        Loads and verifies a durable checkpoint directly from a disk file.
        """
        var opt_f = open(file_path, "r")
        var raw_content = opt_f.read()
        opt_f.close()
        
        var token_pos = 0
        var prompt_count = 0
        var checksum = Int64(0)
        var timestamp = Int64(0)
        
        var lines = raw_content.split("\n")
        for i in range(len(lines)):
            var line_span = lines[i].strip()
            var line_str = String(line_span)
            if line_str.startswith("TOKEN_POS="):
                token_pos = Int(line_str.split("=")[1])
            elif line_str.startswith("PROMPT_COUNT="):
                prompt_count = Int(line_str.split("=")[1])
            elif line_str.startswith("CHECKSUM="):
                checksum = Int64(Int(line_str.split("=")[1]))
            elif line_str.startswith("TIMESTAMP="):
                timestamp = Int64(Int(line_str.split("=")[1]))
                
        var chk = VaultCheckpoint(token_pos, prompt_count, checksum, timestamp, True)
        _ = self.restore_checkpoint_checked(chk)
        self.active_checkpoint = chk
        self.is_checkpointed = True
        return chk
