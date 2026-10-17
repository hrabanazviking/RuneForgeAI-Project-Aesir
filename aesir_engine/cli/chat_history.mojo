"""Read-only, bounded terminal views of committed conversation turns."""

from cli.conversation import ConversationState


comptime HISTORY_PAGE_SIZE = 5


struct PreviewAtom:
    var fragment: String
    var byte_count: Int
    var cells: Int

    def __init__(out self, fragment: String, byte_count: Int, cells: Int):
        self.fragment = fragment
        self.byte_count = byte_count
        self.cells = cells


def _positive_index(text: String, label: String) raises -> Int:
    var clean = String(text.strip())
    if clean == "":
        raise Error("Usage: " + label + " <positive-number>")
    var value = 0
    for byte in clean.as_bytes():
        if byte < 48 or byte > 57:
            raise Error(label + " requires a positive decimal number")
        var digit = Int(byte - 48)
        if value > (2147483647 - digit) // 10:
            raise Error(label + " number exceeds the supported range")
        value = value * 10 + digit
    if value == 0:
        raise Error(label + " number must be positive")
    return value


def _preview_atom(text: String, index: Int) raises -> PreviewAtom:
    """One sanitized scalar; non-ASCII display is charged two cells."""
    var raw = text.as_bytes()
    var first = Int(raw[index])
    if first < 128:
        if first >= 32 and first < 127:
            return PreviewAtom(String(text[byte=index:index + 1]), 1, 1)
        return PreviewAtom(" ", 1, 1)
    var width = 0
    var scalar = 0
    if first >= 194 and first <= 223:
        width = 2
        scalar = first & 31
    elif first >= 224 and first <= 239:
        width = 3
        scalar = first & 15
    elif first >= 240 and first <= 244:
        width = 4
        scalar = first & 7
    var valid = width > 0 and index + width <= len(raw)
    if valid:
        for offset in range(1, width):
            var next_byte = Int(raw[index + offset])
            if next_byte < 128 or next_byte > 191:
                valid = False
                break
            scalar = (scalar << 6) | (next_byte & 63)
        if (width == 2 and scalar < 128
                or width == 3 and scalar < 2048
                or width == 4 and scalar < 65536
                or scalar > 1114111
                or scalar >= 55296 and scalar <= 57343):
            valid = False
    if not valid:
        return PreviewAtom("?", 1, 1)
    if (scalar >= 128 and scalar <= 159
            or scalar == 1564
            or scalar >= 8203 and scalar <= 8207
            or scalar >= 8232 and scalar <= 8238
            or scalar >= 8288 and scalar <= 8303
            or scalar == 65279):
        return PreviewAtom(" ", width, 1)
    return PreviewAtom(String(text[byte=index:index + width]), width, 2)


def safe_turn_preview(text: String, limit: Int) raises -> String:
    """Sanitize UTF-8 and fit a conservative terminal-cell budget."""
    if limit < 1 or limit > 512:
        raise Error("turn preview limit must be within 1..512")
    var raw = text.as_bytes()
    var index = 0
    var shown = 0
    var result = String("")
    var ellipsis_fit = String("")
    while index < len(raw) and shown < limit:
        var atom = _preview_atom(text, index)
        if shown + atom.cells > limit:
            break
        result += atom.fragment
        shown += atom.cells
        index += atom.byte_count
        if shown <= limit - 3:
            ellipsis_fit = result
    if index < len(raw):
        if limit < 3:
            if limit == 1:
                return "."
            return ".."
        return ellipsis_fit + "..."
    return result


struct TurnWindow:
    var text: String
    var pages: Int

    def __init__(out self, text: String, pages: Int):
        self.text = text
        self.pages = pages


def _turn_window(text: String, page: Int, budget: Int) raises -> TurnWindow:
    """Scan bounded committed text once; retain only the requested page."""
    var raw = text.as_bytes()
    var index = 0
    var current_page = 1
    var cells = 0
    var output = String("")
    while index < len(raw):
        var atom = _preview_atom(text, index)
        if cells + atom.cells > budget:
            current_page += 1
            cells = 0
        if current_page == page:
            output += atom.fragment
        cells += atom.cells
        index += atom.byte_count
    return TurnWindow(output, current_page)


def render_history_page(
    conversation: ConversationState, page: Int, columns: Int,
) raises -> String:
    if columns < 24 or columns > 240:
        raise Error("history view width must be 24..240 columns")
    conversation.validate()
    var total = len(conversation.turns)
    if total == 0:
        if page != 1:
            raise Error("history page is outside completed turns")
        if columns < 50:
            return "\n[No completed turns.]\n"
        return "\n[No completed turns. /help lists commands.]\n"
    var pages = (total + HISTORY_PAGE_SIZE - 1) // HISTORY_PAGE_SIZE
    if page < 1 or page > pages:
        raise Error("history page is outside completed turns")
    var frame = String("\nHistory " + String(page) + "/" + String(pages) + "\n")
    if columns >= 50:
        frame = String("\nHistory " + String(page) + "/" + String(pages)
                       + " (newest first)\n")
    var first_number = total - (page - 1) * HISTORY_PAGE_SIZE
    var last_number = first_number - HISTORY_PAGE_SIZE
    if last_number < 0:
        last_number = 0
    # Reserve room for the four-digit max turn ID, labels and ellipsis.
    var preview_limit = columns - 15
    if preview_limit > 60:
        preview_limit = 60
    for number in range(first_number, last_number, -1):
        var turn = conversation.turns[number - 1]
        frame += String(number) + " You: " + safe_turn_preview(turn.user, preview_limit) + "\n"
        frame += "  AI: " + safe_turn_preview(turn.assistant, preview_limit) + "\n"
    if columns < 50:
        frame += "Copy: select text\n/turn N [P]\n/export FILE\n"
    elif columns < 80:
        frame += "Use /turn N; /history P for older.\n"
        frame += "Select text to copy; /export FILE for all.\n"
    else:
        frame += "Use /turn N or /history P; select text to copy; /export FILE for full text.\n"
    return frame


def render_turn_detail(
    conversation: ConversationState, number: Int, columns: Int, page: Int = 1,
) raises -> String:
    if columns < 24 or columns > 240:
        raise Error("turn view width must be 24..240 columns")
    conversation.validate()
    if number < 1 or number > len(conversation.turns):
        raise Error("turn number is outside completed history")
    if page < 1:
        raise Error("turn page must be positive")
    var turn = conversation.turns[number - 1]
    var budget = columns - 8
    var user = _turn_window(turn.user, page, budget)
    var assistant = _turn_window(turn.assistant, page, budget)
    var pages = max(user.pages, assistant.pages)
    if page > pages:
        raise Error("turn page is outside completed text")
    var header = String("\nTurn " + String(number) + " P" + String(page)
                        + "/" + String(pages) + "\n")
    var footer = String("Copy: select text\n/turn N [P]\n/export FILE: full text\n")
    if columns >= 50:
        header = String("\nTurn " + String(number) + "/" + String(len(conversation.turns))
                        + " page " + String(page) + "/" + String(pages) + "\n")
        footer = "Use /turn N P for pages; /export FILE.\nSelect text to copy.\n"
    return String(header + "You: " + user.text
                  + "\nAI: " + assistant.text
                  + "\n" + footer)


def render_history_command(
    command: String, conversation: ConversationState, columns: Int,
) raises -> String:
    var page = 1
    if command != "/history":
        if not command.startswith("/history "):
            raise Error("Usage: /history [page]")
        page = _positive_index(String(command[byte=9:]), "/history")
    return render_history_page(conversation, page, columns)


def render_turn_command(
    command: String, conversation: ConversationState, columns: Int,
) raises -> String:
    if not command.startswith("/turn "):
        raise Error("Usage: /turn <number> [page]")
    var arguments = String(command[byte=6:])
    var parts = arguments.split(" ")
    if len(parts) < 1 or len(parts) > 2:
        raise Error("Usage: /turn <number> [page]")
    var number = _positive_index(String(parts[0]), "/turn")
    var page = 1
    if len(parts) == 2:
        page = _positive_index(String(parts[1]), "/turn page")
    return render_turn_detail(conversation, number, columns, page)


def chat_command_help(columns: Int) -> String:
    if columns < 50:
        return String("\n/help /show /history [P]\n/turn N [P] /compose\n/bye /clear /new\n"
                      + "/model NAME /save FILE\n/load FILE /export FILE\n"
                      + "/set NAME VALUE\nCopy: select text\n")
    return String("\nBrowse: /history [P], /turn N [P], /show\n"
                  + "Compose: /compose (then /send, /undo, /cancel)\n"
                  + "Session: /clear, /new, /bye\n"
                  + "Models: /model NAME (resets conversation)\n"
                  + "Files: /save FILE, /load FILE, /export FILE\n"
                  + "Copy: select text; /export FILE for full text.\n"
                  + "Settings: /set NAME VALUE\n"
                  + "Names: temperature, top-k, top-p, min-p,\n"
                  + "       repeat-penalty, seed, timeout-ms.\n"
                  + "Repetition window is fixed at session creation.\n")
