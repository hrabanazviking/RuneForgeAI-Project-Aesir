# armvegr/session.mojo
# H137 — F1 multi-turn context management on the CPU path (Domain D1 ARMVEGR).
#
# A Session owns one Inference decode state plus the conversation
# transcript. The KV cache IS the prefix cache: continuing a turn only
# prefills the NEW tokens, reusing everything already cached (exactness
# proven by tests/c7_h137_check.mojo Test B). reset() starts a clean
# session (Test C). Chat format follows the H059 TinyLlama lineage:
#   <|system|>\n...\n<|user|>\n...\n<|assistant|>\n...

from armvegr.infer import Inference


struct Session:
    """One multi-turn conversation over a single decode state."""
    var inf: Inference
    var system_text: String
    var history_text: String
    var pending_user_chunk: String

    def __init__(out self, max_seq: Int = 1024):
        self.inf = Inference(max_seq)
        self.system_text = String(
            "<|system|>\nYou are a helpful assistant.\n"
        )
        self.history_text = self.system_text
        self.pending_user_chunk = String("")

    def load(mut self, model_path: String) raises:
        self.inf.load(model_path)

    def free(mut self) raises:
        self.inf.free()

    def reset(mut self):
        """Clean session reset: empty cache position + empty transcript."""
        self.inf.reset()
        self.history_text = self.system_text
        self.pending_user_chunk = String("")

    def build_prompt(mut self, user_text: String) -> String:
        """Full prompt for this turn (history + new user chunk).

        Records the user chunk so commit_assistant() can extend the
        transcript with exactly what was generated from.
        """
        self.pending_user_chunk = (
            String("<|user|>\n") + user_text + String("\n<|assistant|>\n")
        )
        return self.history_text + self.pending_user_chunk

    def commit_assistant(mut self, assistant_text: String):
        """Extend the transcript with the just-generated assistant text."""
        self.history_text = (
            self.history_text + self.pending_user_chunk + assistant_text
            + String("\n")
        )
        self.pending_user_chunk = String("")

    def transcript(self) -> String:
        return self.history_text


def session_version() -> String:
    return "0.1.0"
