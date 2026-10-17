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
    if not draft.move_right() or draft.cursor != 14:
        raise Error("emoji variation selector was not one cursor step")
    if not draft.insert("!") or draft.text() != "A世界🛡️!B":
        raise Error("mid-draft insertion failed")
    if not draft.erase_left() or draft.text() != "A世界🛡️B":
        raise Error("mid-draft deletion failed")
    if not draft.erase_left() or draft.text() != "A世界B":
        raise Error("emoji variation selector deletion was not atomic")
    draft.move_end()
    if draft.move_right() or not draft.erase_left() or draft.text() != "A世界":
        raise Error("end boundary or backspace failed")
    draft.move_home()
    if draft.erase_left() or not draft.insert("/") or draft.text() != "/A世界":
        raise Error("start boundary or command-like insertion failed")
    var accented = CursorDraft()
    if not accented.insert("e\u0301x"):
        raise Error("combining-mark draft setup failed")
    accented.move_home()
    if not accented.move_right() or accented.cursor != 3:
        raise Error("combining mark was not included in right movement")
    if not accented.erase_left() or accented.text() != "x":
        raise Error("combining base and mark were not erased together")
    var attached = CursorDraft()
    if not attached.insert("\u0301"):
        raise Error("leading mark draft setup failed")
    attached.move_home()
    if not attached.insert("e") or attached.cursor != 3 or attached.text() != "e\u0301":
        raise Error("insertion before a mark left cursor inside the glyph")
    var toned = CursorDraft()
    if not toned.insert("👍🏽B"):
        raise Error("skin-tone draft setup failed")
    toned.move_home()
    if not toned.move_right() or toned.cursor != 8:
        raise Error("emoji modifier was not included in right movement")
    toned.move_home()
    if not toned.erase_right() or toned.text() != "B":
        raise Error("emoji modifier was not deleted with its base")
    var controls = CursorDraft()
    if not controls.insert("\n\u0301"):
        raise Error("line break and leading mark setup failed")
    controls.move_home()
    if not controls.move_right() or controls.cursor != 1:
        raise Error("combining mark was incorrectly attached across a line break")
    if not controls.move_right() or controls.cursor != 3:
        raise Error("mark after a line break could not be stepped over")
    if not controls.erase_left() or controls.text() != "\n":
        raise Error("erasing a mark crossed a line break")
    var inserted_break = CursorDraft()
    if not inserted_break.insert("\u0301"):
        raise Error("leading mark setup failed")
    inserted_break.move_home()
    if (not inserted_break.insert("\n") or inserted_break.cursor != 1
            or inserted_break.text() != "\n\u0301"):
        raise Error("inserting a line break absorbed a following mark")
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
