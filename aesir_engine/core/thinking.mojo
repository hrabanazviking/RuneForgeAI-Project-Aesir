# core/thinking.mojo
# Transcript-level thought-tag filter

struct ThinkingController:
    """
    Filters explicit thought tags from decoded text. Tokenizer resolution and
    pre-sampling logit suppression are owned by the sampler, not this helper.
    """
    var enabled: Bool
    var in_thought_block: Bool
    var think_start_tag: String
    var think_end_tag: String

    def __init__(out self):
        self.enabled = True
        self.in_thought_block = False
        self.think_start_tag = String("<think>")
        self.think_end_tag = String("</think>")

    def process_token_text(mut self, token_text: String) -> String:
        """
        Processes token text, stripping out thinking blocks if thinking mode is disabled.
        """
        if self.enabled:
            return token_text

        if self.think_start_tag in token_text:
            self.in_thought_block = True
            return String("")

        if self.think_end_tag in token_text:
            self.in_thought_block = False
            return String("")

        if self.in_thought_block:
            return String("")

        return token_text

def sanitize_thinking_transcript(raw_text: String, thinking_enabled: Bool) -> String:
    """Strips <think>...</think> content if thinking mode is disabled."""
    if thinking_enabled:
        return raw_text

    var out_text = String("")
    var pos = 0
    var text_len = len(raw_text.as_bytes())

    while pos < text_len:
        var start_idx = raw_text.find("<think>", pos)
        if start_idx == -1:
            out_text += String(raw_text[byte=pos:text_len])
            break

        out_text += String(raw_text[byte=pos:start_idx])
        var end_idx = raw_text.find("</think>", start_idx)
        if end_idx == -1:
            break
        pos = end_idx + 8  # Skip len("</think>")

    return out_text
