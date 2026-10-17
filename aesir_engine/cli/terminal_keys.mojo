"""Incremental terminal key classification, independent of chat and termios."""

comptime KEY_PENDING = 0
comptime KEY_TEXT_BYTE = 1
comptime KEY_ENTER = 2
comptime KEY_BACKSPACE = 3
comptime KEY_LEFT = 4
comptime KEY_RIGHT = 5
comptime KEY_UP = 6
comptime KEY_DOWN = 7
comptime KEY_HOME = 8
comptime KEY_END = 9
comptime KEY_DELETE = 10
comptime KEY_ESCAPE = 11
comptime KEY_INTERRUPT = 12
comptime KEY_EOF = 13
comptime KEY_UNKNOWN = 14
comptime KEY_NEWLINE = 15


struct TerminalKey:
    var kind: Int
    var byte: UInt8

    def __init__(out self, kind: Int, byte: UInt8 = 0):
        self.kind = kind
        self.byte = byte


struct TerminalKeyDecoder:
    """Consumes one byte at a time; a caller must flush incomplete escapes."""

    var state: Int
    var sequence_length: Int
    var delete_parameter: Bool

    def __init__(out self):
        self.state = 0
        self.sequence_length = 0
        self.delete_parameter = False

    def flush(mut self) -> TerminalKey:
        var was_escape = self.state == 1
        self.state = 0
        self.sequence_length = 0
        self.delete_parameter = False
        if was_escape:
            return TerminalKey(KEY_ESCAPE)
        return TerminalKey(KEY_UNKNOWN)

    def feed(mut self, byte: UInt8) -> TerminalKey:
        if self.state == 4:
            if byte >= 64 and byte <= 126:
                self.state = 0
                return TerminalKey(KEY_UNKNOWN)
            return TerminalKey(KEY_PENDING)
        if self.state == 3:
            self.state = 0
            if byte == 72:
                return TerminalKey(KEY_HOME)
            if byte == 70:
                return TerminalKey(KEY_END)
            return TerminalKey(KEY_UNKNOWN)
        if self.state == 2:
            self.sequence_length += 1
            if self.sequence_length > 16:
                if byte >= 64 and byte <= 126:
                    self.state = 0
                    self.delete_parameter = False
                    return TerminalKey(KEY_UNKNOWN)
                self.state = 4
                return TerminalKey(KEY_PENDING)
            self.state = 0 if byte >= 64 and byte <= 126 else 2
            if self.sequence_length == 1:
                if byte == 65:
                    return TerminalKey(KEY_UP)
                if byte == 66:
                    return TerminalKey(KEY_DOWN)
                if byte == 67:
                    return TerminalKey(KEY_RIGHT)
                if byte == 68:
                    return TerminalKey(KEY_LEFT)
                if byte == 72:
                    return TerminalKey(KEY_HOME)
                if byte == 70:
                    return TerminalKey(KEY_END)
                if byte == 51:
                    self.delete_parameter = True
                    return TerminalKey(KEY_PENDING)
            if self.sequence_length == 2 and self.delete_parameter and byte == 126:
                self.delete_parameter = False
                return TerminalKey(KEY_DELETE)
            if self.state == 0:
                self.delete_parameter = False
                return TerminalKey(KEY_UNKNOWN)
            return TerminalKey(KEY_PENDING)
        if self.state == 1:
            if byte == 91:
                self.state = 2
                self.sequence_length = 0
                self.delete_parameter = False
                return TerminalKey(KEY_PENDING)
            if byte == 79:
                self.state = 3
                return TerminalKey(KEY_PENDING)
            self.state = 0
            return TerminalKey(KEY_UNKNOWN)
        if byte == 27:
            self.state = 1
            return TerminalKey(KEY_PENDING)
        if byte == 10:
            return TerminalKey(KEY_NEWLINE)
        if byte == 13:
            return TerminalKey(KEY_ENTER)
        if byte == 8 or byte == 127:
            return TerminalKey(KEY_BACKSPACE)
        if byte == 3:
            return TerminalKey(KEY_INTERRUPT)
        if byte == 4:
            return TerminalKey(KEY_EOF)
        if byte >= 32:
            return TerminalKey(KEY_TEXT_BYTE, byte)
        return TerminalKey(KEY_UNKNOWN)
