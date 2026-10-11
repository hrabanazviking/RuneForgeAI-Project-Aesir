"""Batch 2 (R006-R009): native BPE tokenizer family slice tests.

R006 (Llama3 "tool" -> user framing policy) and R007 (Gemma4 "assistant"
alias for "model") live on struct methods that require a real PackedGGUF
model for __init__, so they cannot be unit-tested without a model file.
They are covered by code-path review (see report); the runnable tests here
pin R008 (Gemma 4 newline span splitting) and R009 (GPT-2 regex segment
splits / direct-segment-lookup pre-tokenization).
"""
from loader.llama3_tokenizer import llama3_segments, qwen_segments
from loader.gemma4_tokenizer import gemma4_newline_spans


def _check_spans(text: String, expected: List[String]) raises:
    var spans = gemma4_newline_spans(text)
    if len(spans) != len(expected):
        raise Error("gemma4_newline_spans span count mismatch for '" + text
                    + "': got " + String(len(spans))
                    + ", expected " + String(len(expected)))
    for i in range(len(expected)):
        if spans[i] != expected[i]:
            raise Error("gemma4_newline_spans span mismatch for '" + text
                        + "' at index " + String(i))
    # Round-trip invariant: concatenating spans must reproduce the input.
    var rebuilt = String("")
    for span in spans:
        rebuilt += String(span)
    if rebuilt != text:
        raise Error("gemma4_newline_spans round-trip mismatch for '" + text + "'")


def test_gemma4_newline_spans_basic() raises:
    print("--- gemma4_newline_spans basic ---")
    var basic = List[String]()
    basic.append("a")
    basic.append("\n")
    basic.append("b")
    _check_spans("a\nb", basic)
    var trailing = List[String]()
    trailing.append("abc")
    trailing.append("\n")
    _check_spans("abc\n", trailing)
    var leading = List[String]()
    leading.append("\n")
    leading.append("abc")
    _check_spans("\nabc", leading)
    print("gemma4_newline_spans basic: PASS")


def test_gemma4_newline_spans_edges() raises:
    print("--- gemma4_newline_spans edge cases ---")
    # Empty string -> empty list.
    _check_spans("", List[String]())
    # Newline-only text groups into a single span.
    var only_newlines = List[String]()
    only_newlines.append("\n\n\n")
    _check_spans("\n\n\n", only_newlines)
    # No newlines -> single span with the whole text.
    var plain = List[String]()
    plain.append("hello world")
    _check_spans("hello world", plain)
    # CRLF: \r sticks to the preceding span, \n forms its own.
    var crlf = List[String]()
    crlf.append("a\r")
    crlf.append("\n")
    crlf.append("b")
    _check_spans("a\r\nb", crlf)
    print("gemma4_newline_spans edges: PASS")


def test_gemma4_newline_spans_multibyte() raises:
    print("--- gemma4_newline_spans multibyte (CJK + emoji) ---")
    # 0x0A can never appear inside a multibyte UTF-8 sequence, so byte
    # slicing at newline boundaries must leave every char intact.
    var cjk = List[String]()
    cjk.append("こんにちは")
    cjk.append("\n")
    cjk.append("世界🎉")
    _check_spans("こんにちは\n世界🎉", cjk)
    # Emoji directly adjacent to a newline boundary.
    var emoji = List[String]()
    emoji.append("a🎉")
    emoji.append("\n")
    emoji.append("b")
    _check_spans("a🎉\nb", emoji)
    # 4-byte emoji between two newline runs.
    var sandwich = List[String]()
    sandwich.append("😀")
    sandwich.append("\n\n")
    sandwich.append("🚀")
    _check_spans("😀\n\n🚀", sandwich)
    print("gemma4_newline_spans multibyte: PASS")


def test_llama3_apostrophe_split() raises:
    print("--- llama3_segments apostrophe split ---")
    var segments = llama3_segments("don't")
    if len(segments) != 2:
        raise Error("llama3_segments(\"don't\") must yield 2 segments")
    if segments[0] != "don" or segments[1] != "'t":
        raise Error("llama3_segments(\"don't\") must split to ['don', \"'t'\"]")
    # Additional contractions per the GPT-2 regex suffix table.
    var ll = llama3_segments("I'll")
    if len(ll) != 2 or ll[0] != "I" or ll[1] != "'ll":
        raise Error("llama3_segments(\"I'll\") must split to ['I', \"'ll'\"]")
    print("llama3_segments apostrophe split: PASS")


def test_qwen_digit_run_unsplit() raises:
    print("--- qwen_segments digit run (digit_limit=0 consumes all) ---")
    var segments = qwen_segments("abc12345")
    if len(segments) != 2:
        raise Error("qwen_segments(\"abc12345\") must yield 2 segments")
    if segments[0] != "abc" or segments[1] != "12345":
        raise Error("qwen_segments(\"abc12345\") must split to ['abc', '12345']")
    print("qwen_segments digit run: PASS")


def test_llama3_digit_limit_three() raises:
    print("--- llama3_segments digit_limit=3 ---")
    var segments = llama3_segments("abc12345")
    if len(segments) != 3:
        raise Error("llama3_segments(\"abc12345\") must yield 3 segments")
    if segments[0] != "abc" or segments[1] != "123" or segments[2] != "45":
        raise Error("llama3_segments(\"abc12345\") must split digits at 3: "
                    + "['abc', '123', '45']")
    print("llama3_segments digit limit: PASS")


def main() raises:
    test_gemma4_newline_spans_basic()
    test_gemma4_newline_spans_edges()
    test_gemma4_newline_spans_multibyte()
    test_llama3_apostrophe_split()
    test_qwen_digit_run_unsplit()
    test_llama3_digit_limit_three()
