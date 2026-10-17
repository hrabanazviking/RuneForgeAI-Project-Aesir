"""S33n bounded draft row rendering regressions."""

from cli.chat_compose import COMPOSE_MAX_BYTES
from cli.cursor_draft import CursorDraft
from cli.terminal_editor_view import render_editor_rows
from cli.terminal_view import terminal_preview_atom


def check_rows(draft: CursorDraft, columns: Int, height: Int) raises -> List[String]:
    var frame = render_editor_rows(draft, columns, height)
    if len(frame) != height:
        raise Error("editor frame height changed")
    for row in frame:
        var text = String(row)
        var raw = text.as_bytes()
        var cells = 0
        var index = 0
        while index < len(raw):
            var atom = terminal_preview_atom(text, index)
            if atom.fragment == " " and raw[index] != 32:
                raise Error("unsafe terminal control leaked into editor frame")
            cells += atom.cells
            index += atom.byte_count
        if cells > columns:
            raise Error("editor row exceeded terminal width")
    return frame^


def main() raises:
    var draft = CursorDraft()
    var empty = check_rows(draft, 24, 8)
    if "> |" not in empty[1] or "Line 1/1" not in empty[7]:
        raise Error("empty editor frame lost cursor or status")
    if empty[0] != "Enter send; ^J line; Esc":
        raise Error("narrow editor clipped send, newline or cancel hint")
    var medium = check_rows(draft, 50, 8)
    if medium[0] != "Draft: Enter send | Ctrl+J line | Ctrl+C cancel":
        raise Error("medium editor lost its full control legend")
    var medium_edge = check_rows(draft, 47, 8)
    if medium_edge[0] != medium[0]:
        raise Error("47-column editor clipped its control legend")
    var broad = check_rows(draft, 80, 8)
    if broad[0] != "Draft: Enter send | Ctrl+J line | Esc/Ctrl+C cancel":
        raise Error("wide editor lost Escape or Ctrl+C guidance")
    var broad_edge = check_rows(draft, 51, 8)
    if broad_edge[0] != broad[0]:
        raise Error("51-column editor clipped its control legend")
    if not draft.insert("A世界🛡️B"):
        raise Error("draft insertion failed")
    _ = draft.move_left()
    var unicode = check_rows(draft, 24, 8)
    if "|B" not in unicode[1]:
        raise Error("Unicode cursor marker was misplaced")
    var wide = check_rows(draft, 80, 24)
    if "世界" not in wide[1]:
        raise Error("wide frame lost Unicode text")
    var invalid_dimensions = False
    try:
        _ = render_editor_rows(draft, 23, 8)
    except:
        invalid_dimensions = True
    if not invalid_dimensions:
        raise Error("narrow editor dimensions were accepted")
    var long_draft = CursorDraft()
    if not long_draft.insert(String("x") * 200 + "CURSOR" + String("y") * 200):
        raise Error("long draft rejected")
    for _ in range(200):
        _ = long_draft.move_left()
    var long_frame = check_rows(long_draft, 24, 8)
    if "<" not in long_frame[1] or "|" not in long_frame[1]:
        raise Error("long line lost horizontal cursor window")
    var unicode_long = CursorDraft()
    if not unicode_long.insert(String("界") * 80 + "⚔️" + String("世") * 80):
        raise Error("long Unicode draft rejected")
    for _ in range(80):
        _ = unicode_long.move_left()
    var unicode_window = check_rows(unicode_long, 24, 8)
    if "|" not in unicode_window[1] or "<" not in unicode_window[1]:
        raise Error("long Unicode line lost cursor window")
    var maximum = CursorDraft()
    if not maximum.insert(String("x") * COMPOSE_MAX_BYTES):
        raise Error("maximum-size draft rejected")
    maximum.cursor = COMPOSE_MAX_BYTES // 2
    var maximum_window = check_rows(maximum, 24, 8)
    if "|" not in maximum_window[1] or "65536 bytes" not in maximum_window[7]:
        raise Error("maximum-size draft lost cursor or byte count")
    var many = CursorDraft()
    for number in range(40):
        if not many.insert("row " + String(number) + "\n"):
            raise Error("multiline draft rejected")
    var scrolled = check_rows(many, 24, 8)
    if "Line 41/41" not in scrolled[7] or "> |" not in scrolled[6]:
        raise Error("vertical viewport did not follow cursor")
    var hostile = CursorDraft()
    if not hostile.insert("safe\x1b[31m\x07bad"):
        raise Error("hostile test draft rejected")
    var safe = check_rows(hostile, 24, 8)
    if "\x1b" in safe[1] or "\x07" in safe[1]:
        raise Error("editor frame emitted terminal controls")
    print("editor rows width, viewport, Unicode and control safety: PASS")
