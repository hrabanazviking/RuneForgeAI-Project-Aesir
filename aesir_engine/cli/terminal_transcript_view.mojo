"""Model-free read-only transcript pages for a future terminal viewer."""

from cli.chat_history import render_transcript_window
from cli.conversation import ConversationState


comptime TRANSCRIPT_BACK_PAGES = 128


struct TranscriptPosition(Copyable, ImplicitlyCopyable):
    var turn: Int
    var speaker: Int
    var offset: Int

    def __init__(out self, turn: Int, speaker: Int, offset: Int):
        self.turn = turn
        self.speaker = speaker
        self.offset = offset

    def __copyinit__(out self, existing: Self):
        self.turn = existing.turn
        self.speaker = existing.speaker
        self.offset = existing.offset


struct TranscriptPager:
    """Remember bounded page starts; rendering owns no terminal or model state."""

    var starts: List[TranscriptPosition]
    var current: Int
    var next_position: TranscriptPosition
    var at_end: Bool
    var rendered: Bool
    var last_columns: Int
    var last_rows: Int

    def __init__(out self):
        self.starts = List[TranscriptPosition]()
        self.starts.append(TranscriptPosition(0, 0, -1))
        self.current = 0
        self.next_position = TranscriptPosition(0, 0, -1)
        self.at_end = False
        self.rendered = False
        self.last_columns = 0
        self.last_rows = 0

    def render(
        mut self, conversation: ConversationState, columns: Int, rows: Int,
    ) raises -> List[String]:
        if columns < 24 or columns > 240 or rows < 8 or rows > 80:
            raise Error("transcript view requires 24..240 columns and 8..80 rows")
        var resized = self.last_columns != 0 and (
            self.last_columns != columns or self.last_rows != rows
        )
        var start = self.starts[self.current]
        var window = render_transcript_window(
            conversation, start.turn, start.speaker, start.offset,
            columns, rows - 2,
        )
        if resized:
            self.starts.clear()
            self.starts.append(start)
            self.current = 0
        self.next_position = TranscriptPosition(
            window.turn, window.speaker, window.offset,
        )
        self.at_end = window.done
        self.rendered = True
        self.last_columns = columns
        self.last_rows = rows
        var frame = List[String]()
        var total = len(conversation.turns)
        var display_turn = start.turn + 1
        if total == 0:
            display_turn = 0
        elif display_turn > total:
            display_turn = total
        if columns < 50:
            frame.append("Transcript " + String(display_turn) + "/" + String(total))
        else:
            frame.append("Transcript | turn " + String(display_turn) + "/" + String(total))
        var content = window.text.split("\n")
        for index in range(rows - 2):
            if index < len(content) - 1:
                frame.append(String(content[index]))
            else:
                frame.append("")
        if columns < 50:
            if self.at_end:
                frame.append("End | p prev q back")
            else:
                frame.append("n next p prev q back")
        elif self.at_end and columns < 80:
            frame.append("End of transcript | p previous | q/Esc back")
        elif self.at_end:
            frame.append("End | p previous | q/Esc back | select text to copy")
        elif columns < 80:
            frame.append("n next | p previous | q/Esc back")
        else:
            frame.append("n next | p previous | q/Esc back | select text to copy")
        return frame^

    def advance(mut self) -> Bool:
        if not self.rendered or self.at_end:
            return False
        if self.current + 1 < len(self.starts):
            self.current += 1
        else:
            if len(self.starts) >= TRANSCRIPT_BACK_PAGES:
                _ = self.starts.pop(0)
                self.current -= 1
            self.starts.append(self.next_position)
            self.current += 1
        self.rendered = False
        return True

    def back(mut self) -> Bool:
        if self.current == 0:
            return False
        self.current -= 1
        self.rendered = False
        return True
