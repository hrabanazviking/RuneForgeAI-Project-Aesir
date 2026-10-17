"""S33y bounded chronological transcript frame and navigation regressions."""

from cli.conversation import ConversationState
from cli.terminal_transcript_view import TranscriptPager, TRANSCRIPT_BACK_PAGES
from cli.terminal_view import terminal_preview_atom


def check_frame(frame: List[String], columns: Int, rows: Int) raises:
    if len(frame) != rows:
        raise Error("transcript frame changed terminal height")
    for row in frame:
        var text = String(row)
        var raw = text.as_bytes()
        var index = 0
        var cells = 0
        while index < len(raw):
            var atom = terminal_preview_atom(text, index)
            if atom.fragment == " " and raw[index] != 32:
                raise Error("transcript frame leaked terminal controls")
            cells += atom.cells
            index += atom.byte_count
        if cells > columns:
            raise Error("transcript frame exceeded terminal width")


def main() raises:
    var empty = ConversationState("sha256:fixture", "gemma4", 512, "system", "greedy")
    var blank = TranscriptPager()
    if blank.advance() or blank.back():
        raise Error("unrendered or first transcript page moved")
    var blank_frame = blank.render(empty, 24, 8)
    check_frame(blank_frame, 24, 8)
    if (blank_frame[0] != "Transcript 0/0"
            or "No completed turns" not in blank_frame[1]
            or "End" not in blank_frame[7]):
        raise Error("empty transcript did not explain its end")
    if blank.advance():
        raise Error("empty transcript advanced past its end")
    var tall = blank.render(empty, 80, 80)
    check_frame(tall, 80, 80)
    if "select text" not in tall[79]:
        raise Error("tall empty transcript lost copy guidance")
    var conversation = ConversationState(
        "sha256:fixture", "gemma4", 512, "system", "greedy",
    )
    conversation.append_turn("hello\nworld", "A\x1bB")
    conversation.append_turn("界", "done")
    var pager = TranscriptPager()
    var first = pager.render(conversation, 24, 8)
    check_frame(first, 24, 8)
    if (first[0] != "Transcript 1/2"
            or first[1] != "Turn 1 You:" or first[2] != "hello"
            or first[3] != "world" or first[4] != "Turn 1 AI:"
            or first[5] != "A B" or first[6] != "Turn 2 You:"
            or "n next" not in first[7]):
        raise Error("first transcript frame lost chronological content")
    if not pager.advance():
        raise Error("transcript did not advance across a turn boundary")
    var second = pager.render(conversation, 24, 8)
    check_frame(second, 24, 8)
    if (second[0] != "Transcript 2/2"
            or second[1] != "界" or second[2] != "Turn 2 AI:"
            or second[3] != "done" or "End" not in second[7]
            or pager.advance()):
        raise Error("transcript end page repeated or skipped text")
    if not pager.back():
        raise Error("transcript could not return to its previous page")
    var again = pager.render(conversation, 24, 8)
    if again[1] != first[1] or again[6] != first[6]:
        raise Error("back navigation did not restore the prior page")
    if not pager.advance():
        raise Error("transcript could not revisit its forward page")
    var failed_resize = False
    try:
        _ = pager.render(empty, 80, 8)
    except:
        failed_resize = True
    if not failed_resize or len(pager.starts) != 2 or pager.current != 1:
        raise Error("failed resize render changed transcript history")
    var resized = pager.render(conversation, 80, 8)
    check_frame(resized, 80, 8)
    if (resized[1] != "界" or len(pager.starts) != 1 or pager.back()
            or "select text" not in resized[7]):
        raise Error("resize did not preserve the current cursor and reset back-history")
    var long = ConversationState("sha256:fixture", "gemma4", 512, "system", "greedy")
    long.append_turn("start", String("x") * 30000)
    var bounded = TranscriptPager()
    for _ in range(140):
        var view = bounded.render(long, 24, 8)
        check_frame(view, 24, 8)
        if not bounded.advance():
            raise Error("long transcript stopped before the back-history limit")
        if len(bounded.starts) > TRANSCRIPT_BACK_PAGES:
            raise Error("transcript back-history exceeded its bound")
    if len(bounded.starts) != TRANSCRIPT_BACK_PAGES:
        raise Error("bounded transcript did not retain recent page starts")
    var forward_offset = bounded.starts[bounded.current].offset
    if not bounded.back():
        raise Error("bounded transcript did not retain recent back navigation")
    if forward_offset - bounded.starts[bounded.current].offset != 144:
        raise Error("bounded back navigation skipped or repeated a page")
    var invalid = False
    try:
        _ = pager.render(conversation, 23, 8)
    except:
        invalid = True
    if not invalid:
        raise Error("transcript accepted an undersized viewport")
    if conversation.turns[0].assistant != "A\x1bB":
        raise Error("transcript pager changed committed conversation text")
    print("transcript frames, bounded navigation and resize: PASS")
