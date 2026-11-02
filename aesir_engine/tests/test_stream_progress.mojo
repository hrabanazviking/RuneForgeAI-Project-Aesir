"""Server streaming + progress (J-107): the stream protocol
layer over J-059's proven progress account -- silence on
every kind, the watched sequences at the host cap, at
width 1 and at tile width 4, the ragged final chunk, the
per-kind framing as exact strings, elapsed honesty (no
invented boundary times; the final frame carries the
caller's measured whole-read ms), the stream_options
grammar (J-106's K5 closure: include_usage honoured, the
rest refused by name), the streaming usage decision, and
the Gate's usage chunks (caller-observed counts incl.
cached_tokens, the over-prompt refusal).

No number in this suite is a behaviour of a live server:
no socket was opened, no session started, no inference
ran. The live server leg is deferred-with-reason in the
J-107 doc (section 5), re-cited at the J-118 gate.
"""
from core.prompt_progress import plan_prompt_progress, progress_record
from core.stream_progress import (
    STREAM_NATIVE_NDJSON,
    STREAM_OLLAMA_NDJSON,
    STREAM_OPENAI_SSE,
    progress_frame,
    progress_frames,
    stream_kind_name,
    stream_usage_requested,
)
from server.openai import OpenAIRequest, OpenAIGate


def expect_eq(actual: Int, expected: Int, what: String) raises:
    if actual != expected:
        raise Error(
            "StreamProgress " + what + ": expected " + String(expected)
            + ", got " + String(actual)
        )


def expect_true(cond: Bool, what: String) raises:
    if not cond:
        raise Error("StreamProgress " + what + ": expected true")


def expect_false(cond: Bool, what: String) raises:
    if cond:
        raise Error("StreamProgress " + what + ": expected false")


def expect_str(actual: String, expected: String, what: String) raises:
    if actual != expected:
        raise Error(
            "StreamProgress " + what + ": expected '" + expected
            + "', got '" + actual + "'"
        )


def expect_in(haystack: String, needle: String, what: String) raises:
    if needle not in haystack:
        raise Error(
            "StreamProgress " + what + ": expected '" + needle
            + "' inside '" + haystack + "'"
        )


def expect_not_in(haystack: String, needle: String, what: String) raises:
    if needle in haystack:
        raise Error(
            "StreamProgress " + what + ": did not expect '" + needle
            + "' inside '" + haystack + "'"
        )


def count_frames_with(frames: List[String], needle: String) -> Int:
    var n = 0
    for i in range(len(frames)):
        if needle in frames[i]:
            n += 1
    return n


def test_silence() raises:
    for kind in [STREAM_NATIVE_NDJSON, STREAM_OLLAMA_NDJSON, STREAM_OPENAI_SSE]:
        expect_eq(len(progress_frames(kind, 256, 256)), 0, "short read silent")
        expect_eq(len(progress_frames(kind, 1023, 256)), 0, "sub-threshold silent")
        expect_eq(len(progress_frames(kind, 4096, 8192)), 0, "single-chunk read silent")
        expect_eq(len(progress_frames(kind, 1000, 1)), 0, "width-1 short read silent")
    expect_str(stream_kind_name(STREAM_NATIVE_NDJSON), "native_ndjson", "native kind name")
    expect_str(stream_kind_name(STREAM_OLLAMA_NDJSON), "ollama_ndjson", "ollama kind name")
    expect_str(stream_kind_name(STREAM_OPENAI_SSE), "openai_sse", "openai kind name")
    expect_str(stream_kind_name(99), "UNKNOWN", "kind name fallback")
    print("PASS: silence (zero frames on every kind below the discipline's bounds)")


def test_watched_host_cap() raises:
    var frames = progress_frames(STREAM_NATIVE_NDJSON, 4096, 256)
    expect_eq(len(frames), 10, "4096/256 emits exactly 10 frames")
    var percents = [12, 25, 31, 43, 50, 62, 75, 81, 93, 100]
    var dones = [512, 1024, 1280, 1792, 2048, 2560, 3072, 3328, 3840, 4096]
    for i in range(10):
        expect_in(frames[i], "\"percent\":" + String(percents[i]), "percent ladder")
        expect_in(frames[i], "\"tokens_done\":" + String(dones[i]), "done ladder")
        expect_in(frames[i], "\"prompt_tokens\":4096", "total carried")
    expect_eq(count_frames_with(frames, "\"done\":true"), 1, "exactly one final frame")
    expect_in(frames[9], "\"done\":true", "the final frame is last")
    expect_in(frames[0], "\"done\":false", "the first frame is not final")
    print("PASS: watched sequence at the host cap (4096/256: 10 frames, filed ladder)")


def test_watched_widths() raises:
    var width1 = progress_frames(STREAM_OLLAMA_NDJSON, 4096, 1)
    expect_eq(len(width1), 10, "width-1 4096 emits exactly 10 frames, not 4096")
    expect_in(width1[0], "\"tokens_done\":410", "width-1 first crossing at 410")
    expect_in(width1[0], "\"chunk\":410", "width-1 first chunk index")
    expect_in(width1[0], "\"chunks\":4096", "width-1 chunk count")
    var tile4 = progress_frames(STREAM_OPENAI_SSE, 1024, 4)
    expect_eq(len(tile4), 10, "tile-4 1024 emits exactly 10 frames")
    expect_in(tile4[9], "\"tokens_done\":1024", "tile-4 final total")
    print("PASS: watched sequences at width 1 and tile width 4 (10 frames each)")


def test_ragged_final() raises:
    var frames = progress_frames(STREAM_NATIVE_NDJSON, 1025, 256)
    expect_eq(len(frames), 5, "ragged 1025/256 emits 5 frames")
    expect_in(frames[3], "\"tokens_done\":1024", "boundary 4 reports 1024 read")
    expect_in(frames[3], "\"percent\":99", "boundary 4 at 99 percent")
    expect_in(frames[4], "\"tokens_done\":1025", "final reports the true total, never 1280")
    expect_in(frames[4], "\"percent\":100", "final at 100 percent")
    print("PASS: ragged final chunk (1025/256: 5 frames, true final total)")


def test_framing() raises:
    var payload = String(
        "{\"event\":\"prefill_progress\",\"tokens_done\":256,"
        "\"prompt_tokens\":1024,\"percent\":25,\"chunk\":1,"
        "\"chunks\":4,\"done\":false}"
    )
    var native = progress_frames(STREAM_NATIVE_NDJSON, 1024, 256)
    expect_str(native[0], payload + "\n", "native NDJSON frame is payload + newline")
    var ollama = progress_frames(STREAM_OLLAMA_NDJSON, 1024, 256)
    expect_str(ollama[0], payload + "\n", "ollama NDJSON frame is payload + newline")
    var openai = progress_frames(STREAM_OPENAI_SSE, 1024, 256)
    expect_str(openai[0], "data: " + payload + "\n\n", "openai SSE frame is a data line")
    expect_not_in(native[0], "chat.completion.chunk", "progress is not a completion chunk")
    print("PASS: framing exact per kind (NDJSON line; SSE data line; extension event)")


def test_elapsed_honesty() raises:
    var timed = progress_frames(STREAM_NATIVE_NDJSON, 4096, 256, 1234)
    expect_eq(len(timed), 10, "timed sequence count")
    for i in range(9):
        expect_not_in(timed[i], "elapsed_ms", "non-final frames carry no invented time")
    expect_in(timed[9], "\"elapsed_ms\":1234", "final frame carries the measured whole-read ms")
    var untimed = progress_frames(STREAM_NATIVE_NDJSON, 4096, 256)
    expect_eq(count_frames_with(untimed, "elapsed_ms"), 0, "unstated stays unstated")
    var plan = plan_prompt_progress(4096, 256)
    var silent_record = progress_record(plan, 1)
    expect_false(silent_record.emit, "boundary 1 of 4096/256 does not emit")
    var refused_frame = False
    try:
        _ = progress_frame(STREAM_NATIVE_NDJSON, silent_record)
    except:
        refused_frame = True
    expect_true(refused_frame, "framing a non-emitted record is refused")
    var refused_kind = False
    try:
        _ = progress_frames(99, 4096, 256)
    except:
        refused_kind = True
    expect_true(refused_kind, "an unknown stream kind is refused")
    print("PASS: elapsed honesty (no boundary times invented; final carries the caller's ms)")


def test_stream_options_grammar() raises:
    var asked = OpenAIRequest(
        "{\"model\":\"m\",\"prompt\":\"x\",\"stream\":true,\"stream_options\":{\"include_usage\":true}}")
    expect_true(asked.include_usage, "include_usage true honoured")
    var declined = OpenAIRequest(
        "{\"model\":\"m\",\"prompt\":\"x\",\"stream\":true,\"stream_options\":{\"include_usage\":false}}")
    expect_false(declined.include_usage, "include_usage false honoured")
    var absent = OpenAIRequest("{\"model\":\"m\",\"prompt\":\"x\",\"stream\":true}")
    expect_false(absent.include_usage, "absent stream_options states false")
    var empty = OpenAIRequest(
        "{\"model\":\"m\",\"prompt\":\"x\",\"stream\":true,\"stream_options\":{}}")
    expect_false(empty.include_usage, "empty stream_options states false")
    var chat = OpenAIRequest(
        "{\"model\":\"m\",\"messages\":[{\"role\":\"user\",\"content\":\"Hi\"}],\"stream\":true,\"stream_options\":{\"include_usage\":true}}")
    expect_true(chat.include_usage, "include_usage honoured on the chat shape")
    var refused_unknown = False
    try:
        _ = OpenAIRequest(
            "{\"model\":\"m\",\"prompt\":\"x\",\"stream\":true,\"stream_options\":{\"include_usage\":true,\"other\":1}}")
    except:
        refused_unknown = True
    expect_true(refused_unknown, "an unknown stream_options key is refused by name")
    var refused_dup = False
    try:
        _ = OpenAIRequest(
            "{\"model\":\"m\",\"prompt\":\"x\",\"stream\":true,\"stream_options\":{\"include_usage\":true,\"include_usage\":false}}")
    except:
        refused_dup = True
    expect_true(refused_dup, "a duplicate include_usage is refused")
    var refused_type = False
    try:
        _ = OpenAIRequest(
            "{\"model\":\"m\",\"prompt\":\"x\",\"stream\":true,\"stream_options\":{\"include_usage\":1}}")
    except:
        refused_type = True
    expect_true(refused_type, "a non-boolean include_usage is refused")
    var refused_shape = False
    try:
        _ = OpenAIRequest(
            "{\"model\":\"m\",\"prompt\":\"x\",\"stream\":true,\"stream_options\":true}")
    except:
        refused_shape = True
    expect_true(refused_shape, "a non-object stream_options is refused")
    print("PASS: stream_options grammar (include_usage honoured; the rest refused by name)")


def test_usage_chunks() raises:
    expect_true(stream_usage_requested(True, True), "usage iff streamed and asked")
    expect_false(stream_usage_requested(True, False), "no usage chunk unasked")
    expect_false(stream_usage_requested(False, True), "no usage chunk unstreamed")
    expect_false(stream_usage_requested(False, False), "no usage chunk neither")
    var chat = OpenAIGate.format_chat_usage_chunk(
        "chatcmpl-aesir-7", 1788210000, "m", 4096, 24, 128)
    expect_true(chat.startswith("data: "), "chat usage chunk is an SSE data line")
    expect_in(chat, "\"object\":\"chat.completion.chunk\"", "chat usage chunk object")
    expect_in(chat, "\"choices\":[]", "chat usage chunk carries empty choices")
    expect_in(chat, "\"prompt_tokens\":4096", "chat usage prompt count")
    expect_in(chat, "\"completion_tokens\":24", "chat usage completion count")
    expect_in(chat, "\"total_tokens\":4120", "chat usage total")
    expect_in(chat, "\"cached_tokens\":128", "chat usage cached count (J-106 C3)")
    expect_true(chat.endswith("}}\n\n"), "chat usage chunk terminates the event")
    var completion = OpenAIGate.format_completion_usage_chunk(
        "cmpl-aesir-7", 1788210000, "m", 4096, 24)
    expect_in(completion, "\"object\":\"text_completion\"", "completion usage chunk object")
    expect_in(completion, "\"cached_tokens\":0", "completion usage honest zero default")
    var over = False
    try:
        _ = OpenAIGate.format_chat_usage_chunk(
            "chatcmpl-aesir-7", 1788210000, "m", 10, 3, 11)
    except:
        over = True
    expect_true(over, "a cached count above the prompt count is refused")
    print("PASS: usage chunks (decision rule; both forms; caller-observed counts)")


def main() raises:
    test_silence()
    test_watched_host_cap()
    test_watched_widths()
    test_ragged_final()
    test_framing()
    test_elapsed_honesty()
    test_stream_options_grammar()
    test_usage_chunks()
    print("ALL PASS: stream progress (8 groups)")
