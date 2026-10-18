"""S33ak maximum-size regional-indicator cursor and viewport probe."""

from cli.chat_history import render_transcript_window
from cli.conversation import ConversationState
from core.generation_control import monotonic_milliseconds


def main() raises:
    var conversation = ConversationState(
        "sha256:fixture", "gemma4", 512, "system", "greedy",
    )
    conversation.append_turn("prompt", String("🇺🇸") * 131072)
    var early_start = monotonic_milliseconds()
    var early = render_transcript_window(conversation, 0, 1, 0, 24, 1)
    var early_ms = monotonic_milliseconds() - early_start
    if early.text != String("🇺🇸") * 12 + "\n" or early.offset != 96:
        raise Error("early flag viewport split or skipped a pair")
    var middle_start = monotonic_milliseconds()
    var middle = render_transcript_window(conversation, 0, 1, 524288, 24, 1)
    var middle_ms = monotonic_milliseconds() - middle_start
    if middle.text != early.text or middle.offset != 524384:
        raise Error("middle flag viewport lost its byte continuation")
    var late_start = monotonic_milliseconds()
    var late = render_transcript_window(conversation, 0, 1, 1048568, 24, 1)
    var late_ms = monotonic_milliseconds() - late_start
    if late.text != "🇺🇸\n" or not late.done:
        raise Error("final flag did not finish the maximum assistant turn")
    var invalid_start = monotonic_milliseconds()
    var rejected = False
    try:
        _ = render_transcript_window(conversation, 0, 1, 1048572, 24, 1)
    except:
        rejected = True
    var invalid_ms = monotonic_milliseconds() - invalid_start
    if not rejected:
        raise Error("interior final flag cursor was accepted")
    print(
        "max-RI transcript early/middle/late/reject ms:",
        early_ms, middle_ms, late_ms, invalid_ms,
    )
