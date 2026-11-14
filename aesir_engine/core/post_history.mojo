"""Post-history anchor composition for the native serve (HS-5).

The anchor is a standing instruction re-asserted AFTER the conversation
history on every turn: appended to the composed prompt at turn-composition
time, in final position before generation. It is never written into the
stored conversation history, so a client that resends its history verbatim
never carries the anchor inside it, and the anchor is re-asserted fresh at
full strength each turn instead of being pushed out by a long history.
"""


def resolve_post_history(request_value: String, request_present: Bool,
                         configured: String) -> String:
    """Per-request override wins whenever the field is present -- an
    explicitly empty request value disables the anchor for that turn.
    Otherwise the serve-configured anchor applies."""
    if request_present:
        return request_value
    return configured


def apply_post_history(prompt: String, anchor: String) -> String:
    """Returns the composed prompt with the anchor in final position.
    The caller's prompt string is never mutated; with no anchor the
    prompt is returned unchanged."""
    if anchor == "":
        return prompt
    if prompt == "":
        return anchor
    if prompt.endswith("\n"):
        return prompt + anchor
    return prompt + "\n" + anchor
