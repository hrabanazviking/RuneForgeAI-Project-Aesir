"""S33x bounded, read-only chronological transcript window regressions."""

from cli.chat_history import render_transcript_window
from cli.conversation import ConversationState
from cli.terminal_view import terminal_preview_atom


def check_rows(text: String, columns: Int, maximum: Int) raises:
    var count = 0
    for line in text.split("\n"):
        var row = String(line)
        if row == "" and count == len(text.split("\n")) - 1:
            break
        var cells = 0
        var index = 0
        while index < row.byte_length():
            var atom = terminal_preview_atom(row, index)
            cells += atom.cells
            index += atom.byte_count
        if cells > columns:
            raise Error("transcript row exceeded viewport width")
        count += 1
    if count > maximum:
        raise Error("transcript window exceeded requested row count")


def main() raises:
    var empty = ConversationState("sha256:fixture", "gemma4", 512, "system", "greedy")
    var none = render_transcript_window(empty, 0, 0, -1, 24, 3)
    if none.text != "[No completed turns.]\n" or not none.done:
        raise Error("empty transcript window was not explained")
    var conversation = ConversationState(
        "sha256:fixture", "gemma4", 512, "system", "greedy",
    )
    conversation.append_turn("first\nline", "A\x1bB")
    conversation.append_turn("界x", "")
    var one = render_transcript_window(conversation, 0, 0, -1, 24, 1)
    if (one.text != "Turn 1 You:\n" or one.turn != 0 or one.speaker != 0
            or one.offset != 0 or one.done):
        raise Error("one-row transcript window repeated its header")
    var first = render_transcript_window(conversation, 0, 0, -1, 24, 3)
    if (first.text != "Turn 1 You:\nfirst\nline\n" or first.done
            or first.turn != 0 or first.speaker != 1 or first.offset != -1):
        raise Error("first transcript page lost multiline or continuation")
    var second = render_transcript_window(
        conversation, first.turn, first.speaker, first.offset, 24, 3,
    )
    if (second.text != "Turn 1 AI:\nA B\nTurn 2 You:\n"
            or second.turn != 1 or second.speaker != 0 or second.offset != 0):
        raise Error("transcript did not cross speaker and turn boundaries")
    var third = render_transcript_window(
        conversation, second.turn, second.speaker, second.offset, 24, 3,
    )
    if (third.text != "界x\nTurn 2 AI:\n" or not third.done
            or third.turn != 2 or third.speaker != 0 or third.offset != -1):
        raise Error("transcript final page was incomplete")
    var finished = render_transcript_window(conversation, 2, 0, -1, 24, 3)
    if not finished.done or finished.text != "":
        raise Error("transcript end cursor emitted duplicate text")
    check_rows(first.text, 24, 3)
    check_rows(second.text, 24, 3)
    check_rows(third.text, 24, 3)
    if conversation.turns[0].user != "first\nline":
        raise Error("transcript rendering mutated committed text")
    var unicode = ConversationState("sha256:fixture", "gemma4", 512, "system", "greedy")
    unicode.append_turn(String("界") * 13, "")
    var unicode_first = render_transcript_window(unicode, 0, 0, -1, 24, 2)
    if (unicode_first.text != "Turn 1 You:\n" + String("界") * 12 + "\n"
            or unicode_first.offset != 36 or unicode_first.done):
        raise Error("Unicode window split a scalar or exceeded 24 cells")
    var unicode_last = render_transcript_window(
        unicode, unicode_first.turn, unicode_first.speaker,
        unicode_first.offset, 24, 2,
    )
    if unicode_last.text != "界\nTurn 1 AI:\n" or not unicode_last.done:
        raise Error("Unicode continuation repeated or skipped a scalar")
    check_rows(unicode_first.text, 24, 2)
    var clusters = ConversationState("sha256:fixture", "gemma4", 512, "system", "greedy")
    clusters.append_turn(String("a") * 23 + "e\u0301👩‍👩‍👧‍👦🇺🇸", "")
    var cluster_first = render_transcript_window(clusters, 0, 0, -1, 24, 2)
    if (cluster_first.text != "Turn 1 You:\n" + String("a") * 23 + "e\u0301\n"
            or cluster_first.offset != 26):
        raise Error("accent cluster did not fit the last cell intact")
    var cluster_next = render_transcript_window(
        clusters, cluster_first.turn, cluster_first.speaker,
        cluster_first.offset, 24, 1,
    )
    if (cluster_next.text != "👩‍👩‍👧‍👦🇺🇸\n"
            or cluster_next.done):
        raise Error("emoji or flag cluster split across transcript rows")
    var cluster_end = render_transcript_window(
        clusters, cluster_next.turn, cluster_next.speaker,
        cluster_next.offset, 24, 1,
    )
    if cluster_end.text != "Turn 1 AI:\n" or not cluster_end.done:
        raise Error("cluster transcript did not finish after its AI header")
    check_rows(cluster_first.text, 24, 2)
    check_rows(cluster_next.text, 24, 1)
    var cursor_clusters = ConversationState(
        "sha256:fixture", "gemma4", 512, "system", "greedy",
    )
    cursor_clusters.append_turn("e\u0301👩🏽‍💻🇺🇸🇨🇦Z", "e\u0301👩🏽‍💻🇺🇸🇨🇦Z")
    for bad in [1, 7, 11, 14, 22, 30]:
        for speaker in [0, 1]:
            var rejected = False
            try:
                _ = render_transcript_window(
                    cursor_clusters, 0, speaker, bad, 24, 1,
                )
            except:
                rejected = True
            if not rejected:
                raise Error("transcript accepted a mid-cluster cursor")
    for good in [0, 3, 18, 26, 34]:
        _ = render_transcript_window(cursor_clusters, 0, 0, good, 24, 1)
    var standalone_join = ConversationState(
        "sha256:fixture", "gemma4", 512, "system", "greedy",
    )
    standalone_join.append_turn("A\u200dB", "")
    _ = render_transcript_window(standalone_join, 0, 0, 1, 24, 1)
    _ = render_transcript_window(standalone_join, 0, 0, 4, 24, 1)
    var flag_run = ConversationState(
        "sha256:fixture", "gemma4", 512, "system", "greedy",
    )
    flag_run.append_turn(String("🇺🇸") * 13, "")
    var flag_page = render_transcript_window(flag_run, 0, 0, -1, 24, 2)
    if flag_page.offset != 96 or flag_page.text != (
            "Turn 1 You:\n" + String("🇺🇸") * 12 + "\n"):
        raise Error("plain flag run did not page at a pair boundary")
    var flag_tail = render_transcript_window(
        flag_run, flag_page.turn, flag_page.speaker,
        flag_page.offset, 24, 1,
    )
    if flag_tail.text != "🇺🇸\n":
        raise Error("valid flag continuation was rejected or split")
    var exact = ConversationState("sha256:fixture", "gemma4", 512, "system", "greedy")
    exact.append_turn(String("x") * 24 + "\ny", "")
    var exact_first = render_transcript_window(exact, 0, 0, -1, 24, 2)
    if exact_first.text != "Turn 1 You:\n" + String("x") * 24 + "\n"
            or exact_first.offset != 25:
        raise Error("exact-width source newline was not consumed")
    var exact_next = render_transcript_window(
        exact, exact_first.turn, exact_first.speaker, exact_first.offset, 24, 1,
    )
    if exact_next.text != "y\n":
        raise Error("exact-width newline inserted a spurious blank row")
    var huge = ConversationState("sha256:fixture", "gemma4", 512, "system", "greedy")
    huge.append_turn("prompt", String("x") * 1048576)
    var small = render_transcript_window(huge, 0, 1, -1, 24, 4)
    if (small.text != "Turn 1 AI:\n" + String("x") * 24 + "\n"
            + String("x") * 24 + "\n" + String("x") * 24 + "\n"
            or small.turn != 0 or small.speaker != 1 or small.offset != 72
            or small.done):
        raise Error("maximum turn was not bounded to one viewport")
    check_rows(small.text, 24, 4)
    var resumed = render_transcript_window(
        huge, small.turn, small.speaker, small.offset, 24, 4,
    )
    if (resumed.text != (String("x") * 24 + "\n") * 4
            or resumed.offset != 168 or resumed.done):
        raise Error("long assistant continuation lost its exact byte cursor")
    var final_byte = render_transcript_window(huge, 0, 1, 1048575, 24, 2)
    if final_byte.text != "x\n" or not final_byte.done:
        raise Error("long assistant final byte was lost")
    var wide = render_transcript_window(huge, 0, 1, -1, 240, 80)
    if wide.offset != 79 * 240 or wide.done:
        raise Error("wide transcript window exceeded its bounded page")
    check_rows(wide.text, 240, 80)
    for width in [23, 241]:
        var rejected = False
        try:
            _ = render_transcript_window(conversation, 0, 0, -1, width, 3)
        except:
            rejected = True
        if not rejected:
            raise Error("transcript accepted an invalid width")
    for row_count in [0, 81]:
        var rejected = False
        try:
            _ = render_transcript_window(conversation, 0, 0, -1, 24, row_count)
        except:
            rejected = True
        if not rejected:
            raise Error("transcript accepted an invalid row count")
    for turn, speaker, offset in [
        (3, 0, -1), (0, 2, -1), (0, 0, 100), (1, 0, 1), (2, 0, 0),
    ]:
        var rejected = False
        try:
            _ = render_transcript_window(
                conversation, turn, speaker, offset, 24, 3,
            )
        except:
            rejected = True
        if not rejected:
            raise Error("transcript accepted an invalid continuation cursor")
    print("chronological transcript window, bounds and continuation: PASS")
