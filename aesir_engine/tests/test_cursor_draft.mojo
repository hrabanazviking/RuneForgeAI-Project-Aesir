"""S33j model-free UTF-8 cursor-state regressions."""

from cli.chat_compose import COMPOSE_MAX_BYTES, COMPOSE_MAX_LINES
from cli.cursor_draft import CursorDraft


def main() raises:
    var draft = CursorDraft()
    if draft.move_left() or draft.move_right() or draft.erase_left() or draft.erase_right():
        raise Error("empty draft moved or erased")
    if not draft.insert("A世界🛡️B"):
        raise Error("UTF-8 insertion failed")
    draft.move_home()
    if not draft.move_right() or draft.cursor != 1:
        raise Error("ASCII movement failed")
    if not draft.move_right() or draft.cursor != 4:
        raise Error("CJK boundary failed")
    if not draft.move_right() or draft.cursor != 7:
        raise Error("second CJK boundary failed")
    if not draft.move_right() or draft.cursor != 11:
        raise Error("emoji boundary failed")
    if not draft.move_right() or draft.cursor != 14:
        raise Error("variation selector boundary failed")
    if not draft.insert("!") or draft.text() != "A世界🛡️!B":
        raise Error("mid-draft insertion failed")
    if not draft.erase_left() or draft.text() != "A世界🛡️B":
        raise Error("mid-draft deletion failed")
    if not draft.erase_left() or draft.text() != "A世界🛡B":
        raise Error("UTF-8 scalar deletion failed")
    draft.move_end()
    if draft.move_right() or not draft.erase_left() or draft.text() != "A世界🛡":
        raise Error("end boundary or backspace failed")
    draft.move_home()
    if draft.erase_left() or not draft.insert("/") or draft.text() != "/A世界🛡":
        raise Error("start boundary or command-like insertion failed")
    var forward = CursorDraft()
    if not forward.insert("A界B"):
        raise Error("forward-delete draft setup failed")
    forward.move_home()
    _ = forward.move_right()
    if not forward.erase_right() or forward.text() != "AB" or forward.cursor != 1:
        raise Error("forward deletion did not preserve UTF-8 boundary")
    forward.move_end()
    if forward.erase_right():
        raise Error("forward deletion crossed end boundary")
    var bounded = CursorDraft()
    if not bounded.insert(String("x") * COMPOSE_MAX_BYTES):
        raise Error("exact 64 KiB limit rejected")
    bounded.move_home()
    if bounded.insert("y") or bounded.cursor != 0 or bounded.text().byte_length() != COMPOSE_MAX_BYTES:
        raise Error("over-limit insertion changed draft or cursor")
    if not bounded.move_right() or not bounded.erase_left():
        raise Error("capacity was not released after deletion")
    if bounded.insert("世界") or not bounded.insert("y"):
        raise Error("replacement ignored remaining byte capacity")
    if bounded.text().byte_length() != COMPOSE_MAX_BYTES:
        raise Error("replacement changed the exact byte limit")
    var multiline = CursorDraft()
    if not multiline.insert(String("\n") * (COMPOSE_MAX_LINES - 1)):
        raise Error("exact 128-line limit rejected")
    if multiline.insert("\n") or multiline.cursor != COMPOSE_MAX_LINES - 1:
        raise Error("line-limit rejection changed draft or cursor")
    if not multiline.erase_left() or not multiline.insert("\n"):
        raise Error("line capacity was not released after deletion")
    print("cursor draft UTF-8 boundaries and byte limits: PASS")
