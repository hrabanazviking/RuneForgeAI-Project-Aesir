"""Model-free PTY entry point for the user-facing /edit reader."""

from cli.chat_editor import read_chat_editor


def main() raises:
    var result = read_chat_editor(-1)
    if result.submitted:
        print("SUBMITTED=" + result.text)
    elif result.eof:
        print("EDITOR_EOF")
    else:
        print("EDITOR_CANCELLED")
