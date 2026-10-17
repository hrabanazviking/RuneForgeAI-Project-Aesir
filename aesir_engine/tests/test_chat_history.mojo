"""S33b read-only transcript navigation and safe preview regressions."""

from cli.conversation import ConversationState, ConversationTurn
from cli.chat_history import (
    chat_command_help, render_history_command, render_history_page,
    render_turn_command, render_turn_detail, safe_turn_preview,
)


def main() raises:
    var conversation = ConversationState(
        "sha256:fixture", "gemma4", 512, "system", "greedy",
    )
    if "No completed turns" not in render_history_page(conversation, 1, 24):
        raise Error("empty history was not explained")
    var invalid_empty_page = False
    try:
        _ = render_history_page(conversation, 2, 24)
    except:
        invalid_empty_page = True
    if not invalid_empty_page:
        raise Error("empty history accepted page two")
    for number in range(1, 13):
        conversation.append_turn("user " + String(number), "answer " + String(number))
    var newest = render_history_command("/history", conversation, 24)
    var middle = render_history_command("/history 2", conversation, 80)
    var oldest = render_history_command("/history 3", conversation, 80)
    if ("12 You:" not in newest or "8 You:" not in newest
            or "7 You:" in newest or "7 You:" not in middle
            or "3 You:" not in middle or "2 You:" not in oldest
            or "1 You:" not in oldest):
        raise Error("history navigation skipped or reordered turns")
    for line in newest.split("\n"):
        if String(line).byte_length() > 24:
            raise Error("24-column history page overflowed")
    for width in [24, 50, 79, 80]:
        var page = render_history_page(conversation, 1, width)
        var detail = render_turn_command("/turn 1", conversation, width)
        if (("select text" not in page and "Select text" not in page)
                or ("select text" not in detail and "Select text" not in detail)):
            raise Error("copy/export guidance is missing")
        for line in page.split("\n"):
            if String(line).byte_length() > width:
                raise Error("history guidance overflowed terminal width")
        for line in detail.split("\n"):
            if String(line).byte_length() > width:
                raise Error("turn guidance overflowed terminal width")
    var full_history = ConversationState(
        "sha256:fixture", "gemma4", 512, "system", "greedy",
    )
    for _ in range(1024):
        full_history.turns.append(ConversationTurn(String("x") * 80, "answer"))
    var last_page = render_history_page(full_history, 1, 24)
    if "1024 You:" not in last_page:
        raise Error("four-digit turn ID was not shown")
    for line in last_page.split("\n"):
        if String(line).byte_length() > 24:
            raise Error("four-digit history page overflowed")
    if "user 3" not in render_turn_command("/turn 3", conversation, 80):
        raise Error("numbered turn did not show its own content")
    for bad in ["/history 0", "/history -1", "/history 4", "/history 1x"]:
        var rejected = False
        try:
            _ = render_history_command(bad, conversation, 80)
        except:
            rejected = True
        if not rejected:
            raise Error("history accepted invalid page: " + bad)
    for bad in ["/turn", "/turn 0", "/turn 13", "/turn 1 0",
                "/turn 1 2", "/turn 1 2 3", "/turn 999999999999999999999"]:
        var rejected = False
        try:
            _ = render_turn_command(bad, conversation, 80)
        except:
            rejected = True
        if not rejected:
            raise Error("turn view accepted invalid number: " + bad)
    var unicode = safe_turn_preview("héllo 🛡️", 20)
    if "héllo 🛡️" not in unicode:
        raise Error("Unicode preview lost valid text")
    if (safe_turn_preview(String("界") * 20, 9) != "界界界..."
            or safe_turn_preview(String("a") * 10, 9) != "aaaaaa..."
            or safe_turn_preview(String("a") * 9, 9) != "aaaaaaaaa"
            or safe_turn_preview("界", 1) != "."):
        raise Error("preview did not reserve a bounded cell-width ellipsis")
    var mixed = ConversationState(
        "sha256:fixture", "gemma4", 512, "system", "greedy",
    )
    mixed.append_turn(String("界") * 100, String("🛡️") * 100)
    var mixed_page = render_history_page(mixed, 1, 24)
    var mixed_detail = render_turn_detail(mixed, 1, 24)
    if ("1 You: 界界界..." not in mixed_page
            or "Turn 1 P1/25" not in mixed_detail
            or "You: 界界界界界界界界" not in mixed_detail):
        raise Error("narrow mixed-script views were not cell-bounded")
    var last_mixed = render_turn_command("/turn 1 25", mixed, 24)
    if "Turn 1 P25/25" not in last_mixed or "You: \n" not in last_mixed:
        raise Error("last mixed-script page skipped or repeated user text")
    var no_page_26 = False
    try:
        _ = render_turn_command("/turn 1 26", mixed, 24)
    except:
        no_page_26 = True
    if not no_page_26:
        raise Error("turn page beyond the end was accepted")
    var paged = ConversationState(
        "sha256:fixture", "gemma4", 512, "system", "greedy",
    )
    paged.append_turn(String("x") * 35, String("y") * 18)
    var first = render_turn_command("/turn 1", paged, 24)
    var second = render_turn_command("/turn 1 2", paged, 24)
    var third = render_turn_command("/turn 1 3", paged, 24)
    if ("P1/3" not in first or "You: " + String("x") * 16 not in first
            or "P2/3" not in second or "AI: yy" not in second
            or "P3/3" not in third or "You: xxx" not in third):
        raise Error("turn pages lost, repeated or misnumbered text")
    var huge = ConversationState(
        "sha256:fixture", "gemma4", 512, "system", "greedy",
    )
    huge.append_turn("question", String("a") * 1048576)
    var last_huge = render_turn_command("/turn 1 4520", huge, 240)
    if "page 4520/4520" not in last_huge or "AI: " + String("a") * 168 not in last_huge:
        raise Error("maximum assistant turn was not paged through its final bytes")
    var narrow_huge = render_turn_command("/turn 1 65536", huge, 24)
    if "Turn 1 P65536/65536" not in narrow_huge or "AI: " + String("a") * 16 not in narrow_huge:
        raise Error("maximum assistant turn lost its narrow final page")
    for line in narrow_huge.split("\n"):
        if String(line).byte_length() > 24:
            raise Error("maximum turn page overflowed 24 columns")
    for width in [24, 50, 80]:
        for line in render_turn_detail(mixed, 1, width).split("\n"):
            # Every non-ASCII scalar is charged two cells, so byte length
            # is not an appropriate terminal-width assertion here.
            if String(line).byte_length() > width * 4:
                raise Error("mixed-script turn detail was unbounded")
    var sanitized = safe_turn_preview("a\nb\tc", 20)
    if "\n" in sanitized or "\t" in sanitized or sanitized != "a b c":
        raise Error("terminal controls leaked into history preview")
    if "..." not in safe_turn_preview(String("x") * 1000, 12):
        raise Error("long turn preview was not bounded")
    if ("/history" not in chat_command_help(24)
            or "/compose" not in chat_command_help(24)
            or "/compose" not in chat_command_help(80)
            or "/edit" not in chat_command_help(24)
            or "/edit" not in chat_command_help(80)
            or "/export" not in chat_command_help(80)
            or "select text" not in chat_command_help(80)):
        raise Error("command discovery omitted history/compose/copy/export")
    for line in chat_command_help(24).split("\n"):
        if String(line).byte_length() > 24:
            raise Error("narrow command help overflowed")
    for line in chat_command_help(50).split("\n"):
        if String(line).byte_length() > 50:
            raise Error("wide command help overflowed its declared width")
    if len(conversation.turns) != 12:
        raise Error("history rendering mutated conversation state")
    print("chat history unit: PASS")
