"""Model-free PTY entry point for the read-only transcript viewer."""

from cli.conversation import ConversationState
from cli.chat_transcript_viewer import read_chat_transcript


def main() raises:
    var conversation = ConversationState(
        "sha256:fixture", "gemma4", 512, "system", "greedy",
    )
    conversation.append_turn("hello\nworld", "A\x1bB")
    conversation.append_turn("界", "done")
    if read_chat_transcript(conversation):
        print("TRANSCRIPT_EXIT")
    else:
        print("TRANSCRIPT_UNAVAILABLE")
