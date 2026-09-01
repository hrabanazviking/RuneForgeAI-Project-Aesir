# core/thinking.mojo
# Bounded transcript redaction for the literal <think>...</think> convention.


def _suffix_prefix_length(text: String, marker: String) -> Int:
    """Returns the longest text suffix that is a proper marker prefix."""
    var max_len = min(text.byte_length(), marker.byte_length() - 1)
    var candidate = max_len
    while candidate > 0:
        var text_start = text.byte_length() - candidate
        if (
            String(text[byte=text_start : text.byte_length()])
            == String(marker[byte=0:candidate])
        ):
            return candidate
        candidate -= 1
    return 0


struct ThinkingController:
    """Streaming redactor for one exact, explicitly bounded tag convention."""

    var enabled: Bool
    var in_thought_block: Bool
    var think_start_tag: String
    var think_end_tag: String
    var pending: String

    def __init__(out self, enabled: Bool = True):
        self.enabled = enabled
        self.in_thought_block = False
        self.think_start_tag = String("<think>")
        self.think_end_tag = String("</think>")
        self.pending = String("")

    def process_token_text(mut self, token_text: String) raises -> String:
        """
        Redacts disabled thought blocks across arbitrary token boundaries.

        A short marker-prefix suffix is retained until the next call, preventing
        split tags such as "<thi" + "nk>" from leaking. Call finish() after the
        final token.
        """
        if self.enabled:
            if self.in_thought_block or self.pending.byte_length() > 0:
                raise Error("ThinkingController mode cannot change mid-stream")
            return token_text
        if self.pending.byte_length() + token_text.byte_length() > 1048576:
            raise Error("ThinkingController pending input exceeds 1 MiB")
        self.pending += token_text
        var output = String("")

        while self.pending.byte_length() > 0:
            if self.in_thought_block:
                var end_index = self.pending.find(self.think_end_tag)
                if end_index < 0:
                    var keep = _suffix_prefix_length(
                        self.pending, self.think_end_tag
                    )
                    if keep > 0:
                        var retained = String(
                            self.pending[
                                byte=self.pending.byte_length() - keep :
                            ]
                        )
                        self.pending = retained
                    else:
                        self.pending = String("")
                    return output
                var after_end = String(
                    self.pending[
                        byte=end_index + self.think_end_tag.byte_length() :
                    ]
                )
                self.pending = after_end
                self.in_thought_block = False
                continue

            var stray_end = self.pending.find(self.think_end_tag)
            var start_index = self.pending.find(self.think_start_tag)
            if stray_end >= 0 and (start_index < 0 or stray_end < start_index):
                raise Error("ThinkingController found a closing tag without an open block")
            if start_index >= 0:
                output += String(self.pending[byte=0:start_index])
                var after_start = String(
                    self.pending[
                        byte=start_index + self.think_start_tag.byte_length() :
                    ]
                )
                self.pending = after_start
                self.in_thought_block = True
                continue

            var keep = _suffix_prefix_length(self.pending, self.think_start_tag)
            var emit_count = self.pending.byte_length() - keep
            if emit_count > 0:
                output += String(self.pending[byte=0:emit_count])
            if keep > 0:
                var retained = String(self.pending[byte=emit_count:])
                self.pending = retained
            else:
                self.pending = String("")
            return output
        return output

    def finish(mut self) raises -> String:
        """Flushes visible suffixes and rejects an unterminated thought block."""
        if self.enabled:
            if self.pending.byte_length() > 0 or self.in_thought_block:
                raise Error("ThinkingController enabled stream has invalid state")
            return String("")
        if self.in_thought_block:
            self.pending = String("")
            raise Error("ThinkingController thought block is unterminated")
        var result = self.pending
        self.pending = String("")
        return result


def sanitize_thinking_transcript(
    raw_text: String, thinking_enabled: Bool
) raises -> String:
    """Redacts a complete transcript using the streaming implementation."""
    var controller = ThinkingController(thinking_enabled)
    var result = controller.process_token_text(raw_text)
    result += controller.finish()
    return result
