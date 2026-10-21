from std.sys import argv
from smidr.window_policy import window_key_admitted


def main() raises:
    var a = argv()
    if len(a) == 2 and a[1] == "grid":
        var text = String("[")
        var first = True
        for width in List[Int]([0, 1, 2, 3, 4, 8, 64, 9223372036854775807]):
            for position in range(17):
                for key in range(20):
                    if not first:
                        text += ","
                    first = False
                    text += "[" + String(position) + "," + String(key) + "," + String(width) + "," + String("true" if window_key_admitted(position, key, width) else "false") + "]"
        print(text + "]")
        return
    if len(a) != 4:
        raise Error("expected absolute_position key window_width")
    print(String("{\"admitted\":") + String("true" if window_key_admitted(Int(a[1]), Int(a[2]), Int(a[3])) else "false") + "}")
