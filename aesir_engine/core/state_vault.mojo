# core/state_vault.mojo
# StateVault: in-memory checkpoint marker scaffold

from std.memory import Pointer
from core.mimir_well import Scalar, f16

struct StateVault(Copyable, ImplicitlyCopyable):
    """
    ᛋᛏᚨᛏᛖ·ᚠᚨᚢᛚᛏ — The Vault of Unbroken State (StateVault)
    ═════════════════════════════════════════════════════════
    Stores token-position and prompt-count markers in the current process. It
    does not snapshot KV memory, persist data, or recover a crashed runtime.
    """
    var is_checkpointed: Bool
    var last_token_pos: Int
    var prompt_tokens_count: Int

    def __init__(out self):
        self.is_checkpointed = False
        self.last_token_pos = 0
        self.prompt_tokens_count = 0

    def copy(self) -> Self:
        var v = Self()
        v.is_checkpointed = self.is_checkpointed
        v.last_token_pos = self.last_token_pos
        v.prompt_tokens_count = self.prompt_tokens_count
        return v

    def save_checkpoint(mut self, token_pos: Int, prompt_count: Int):
        """
        ᛋᚨᚠᛖ·ᚲᚺᛖᚲᚴᛈᛟᛁᚾᛏ — The Inscription of the Snapshot (save_checkpoint)
        ═════════════════════════════════════════════════════════════════════
        Stores the current token position and prompt count as local fields.
        """
        if token_pos < 0 or prompt_count < 0:
            return
        self.last_token_pos = token_pos
        self.prompt_tokens_count = prompt_count
        self.is_checkpointed = True

    def restore_checkpoint(self) -> Int:
        """
        ᚱᛖᛋᛏᛟᚱᛖ·ᚲᚺᛖᚲᚴᛈᛟᛁᚾᛏ — The Recall of Fate (restore_checkpoint)
        ═════════════════════════════════════════════════════════════════
        Returns the last locally stored token-position marker.
        """
        if not self.is_checkpointed:
            return 0
        return self.last_token_pos
