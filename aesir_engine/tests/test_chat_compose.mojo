"""S33c bounded multiline draft regressions."""

from cli.chat_compose import ChatDraft, COMPOSE_MAX_BYTES, COMPOSE_MAX_LINES


def main() raises:
    var draft = ChatDraft()
    if draft.prompt() != "" or draft.undo():
        raise Error("empty draft changed")
    if not draft.append("/bye") or not draft.append("") or not draft.append("世界 🛡️"):
        raise Error("Unicode/blank draft lines were rejected")
    if draft.prompt() != "/bye\n\n世界 🛡️":
        raise Error("draft lost command-like content, blank line or Unicode")
    if not draft.undo() or draft.prompt() != "/bye\n":
        raise Error("undo did not preserve the preceding blank line")
    if not draft.append("/send") or draft.prompt() != "/bye\n\n/send":
        raise Error("command-like content was changed")
    var bounded = ChatDraft()
    if not bounded.append(String("x") * COMPOSE_MAX_BYTES):
        raise Error("exact byte limit was rejected")
    if bounded.append("") or bounded.append("y"):
        raise Error("byte limit accepted a separator or another line")
    if not bounded.undo() or bounded.bytes_used != 0 or not bounded.append("ok"):
        raise Error("undo did not restore byte capacity")
    var lines = ChatDraft()
    for _ in range(COMPOSE_MAX_LINES):
        if not lines.append(""):
            raise Error("line bound was rejected too early")
    if lines.append("last") or lines.bytes_used != COMPOSE_MAX_LINES - 1:
        raise Error("line bound or newline accounting failed")
    print("chat compose draft bounds, Unicode, blank lines, undo: PASS")
