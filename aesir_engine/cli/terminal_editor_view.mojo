"""Pure, bounded terminal rows for a future native cursor editor."""

from cli.cursor_draft import CursorDraft
from cli.terminal_view import terminal_preview_atom


def _safe_prefix(text: String, budget: Int) raises -> String:
    var raw = text.as_bytes()
    var index = 0
    var cells = 0
    var result = String("")
    var ellipsis_fit = String("")
    while index < len(raw):
        var atom = terminal_preview_atom(text, index)
        if cells + atom.cells > budget:
            return ellipsis_fit + "..."
        result += atom.fragment
        cells += atom.cells
        index += atom.byte_count
        if cells <= budget - 3:
            ellipsis_fit = result
    return result


def _safe_tail(text: String, budget: Int) raises -> String:
    var raw = text.as_bytes()
    var index = 0
    var start = 0
    var cells = 0
    while index < len(raw):
        var atom = terminal_preview_atom(text, index)
        cells += atom.cells
        index += atom.byte_count
        while cells > budget:
            var dropped = terminal_preview_atom(text, start)
            cells -= dropped.cells
            start += dropped.byte_count
    if start > 0:
        while cells > budget - 1:
            var dropped = terminal_preview_atom(text, start)
            cells -= dropped.cells
            start += dropped.byte_count
    var result = String("<") if start > 0 else String("")
    index = start
    while index < len(raw):
        var atom = terminal_preview_atom(text, index)
        result += atom.fragment
        index += atom.byte_count
    return result


def _active_line(line: String, cursor: Int, columns: Int) raises -> String:
    var left_budget = (columns - 3) // 2
    var right_budget = columns - 3 - left_budget
    var before = String(line[byte=0:cursor])
    var after = String(line[byte=cursor:])
    return "> " + _safe_tail(before, left_budget) + "|" + _safe_prefix(after, right_budget)


def render_editor_rows(
    draft: CursorDraft, columns: Int, rows: Int, notice: String = "",
) raises -> List[String]:
    """Return exactly rows sanitized lines, with cursor context always visible."""
    if columns < 24 or columns > 240 or rows < 8 or rows > 80:
        raise Error("editor view requires 24..240 columns and 8..80 rows")
    var lines = List[String]()
    for line in draft.text().split("\n"):
        lines.append(String(line))
    var raw = draft.text().as_bytes()
    var cursor_line = 0
    var line_start = 0
    for index in range(draft.cursor):
        if raw[index] == 10:
            cursor_line += 1
            line_start = index + 1
    var visible = rows - 2
    var first = cursor_line - visible // 2
    if first < 0:
        first = 0
    var final_first = len(lines) - visible
    if final_first < 0:
        final_first = 0
    if first > final_first:
        first = final_first
    var result = List[String]()
    result.append(_safe_prefix("Draft: Enter send | Ctrl+J line | Ctrl+C cancel", columns))
    for row in range(visible):
        var source = first + row
        if source >= len(lines):
            result.append("")
        elif source == cursor_line:
            result.append(_active_line(lines[source], draft.cursor - line_start, columns))
        else:
            result.append("  " + _safe_prefix(lines[source], columns - 2))
    if notice != "":
        result.append(_safe_prefix(notice, columns))
    else:
        result.append(_safe_prefix(
            "Line " + String(cursor_line + 1) + "/" + String(len(lines))
            + " | " + String(draft.text().byte_length()) + " bytes", columns,
        ))
    return result^
