"""Small redirected-input harness for composer EOF, without model loading."""

from cli.chat_compose import read_chat_compose


def main() raises:
    var result = read_chat_compose(-1)
    if result.submitted:
        print("RESULT submitted " + result.text)
    elif result.eof:
        print("RESULT eof")
    else:
        print("RESULT cancelled")
