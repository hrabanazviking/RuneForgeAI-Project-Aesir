"""Opt-in slice 5 end-to-end image chat proof on the real pair,
CUDA-session path (convergence slice, roadmap S-171/S-172).

Usage: image_chat_cuda_mmproj <model.gguf> <mmproj.gguf> <red.ppm> <blue.ppm>

The generic-path sibling (tests/image_chat_mmproj.mojo) proves the
same three gates through AesirEngine on hosts whose codegen reaches
the generic forward. This port drives Gemma4CUDASession instead:
the encoder's soft rows are armed on the session and forward()
substitutes them over the marker token's embedding inside the
native CUDA prefill.

Section A (forward control, bit-exact): one run prefills the
marker-expanded prompt plainly; a second arms a CONTROL span whose
rows embedding_kernel itself produced from the marker token. The
sampled token streams must be identical — the substitution
machinery contributes the rows and nothing else.

Section B (behaviour): the real encoder rows for a solid red and a
solid blue image are armed in turn; the answers to "What is the
dominant color of this image?" must track the images.

Section C (text-only control): the same question with no image.
"""
from std.sys import argv
from core.gemma4_cuda import Gemma4CUDASession
from core.vision_encoder import encode_image_rows
from loader.tokenizer import RuneStreamDecoder


def contains_word(text: String, word: String) -> Bool:
    var t = text.as_bytes()
    var w = word.as_bytes()
    if len(w) == 0 or len(t) < len(w):
        return False
    for i in range(len(t) - len(w) + 1):
        var ok = True
        for j in range(len(w)):
            var c = t[i + j]
            if c >= 65 and c <= 90:
                c += 32
            if c != w[j]:
                ok = False
                break
        if ok:
            return True
    return False


def build_tokens(mut session: Gemma4CUDASession, with_image: Bool,
                 n_soft: Int, mut tokens: List[Int]) raises -> Int:
    # Mirrors append_message's own construction with the image as an
    # interrupted content part: the marker enters via control(),
    # because Gemma4Tokenizer.encode does not resolve special spellings.
    tokens.clear()
    tokens.append(session.tokenizer.vocabulary.bos_token_id)
    tokens.append(session.tokenizer.control("<|turn>"))
    session.tokenizer.append_text(tokens, "user\n")
    var span_start = -1
    if with_image:
        span_start = len(tokens)
        var marker = session.tokenizer.control("<|image|>")
        for _ in range(n_soft):
            tokens.append(marker)
    session.tokenizer.append_text(
        tokens, "What is the dominant color of this image?")
    tokens.append(session.tokenizer.control("<turn|>"))
    session.tokenizer.append_text(tokens, "\n")
    session.tokenizer.append_generation_prompt(tokens)
    return span_start


def run_turn(mut session: Gemma4CUDASession, tokens: List[Int],
             mut ids: List[Int]) raises -> String:
    ids.clear()
    var next_token = -1
    for i in range(len(tokens)):
        next_token = session.forward(tokens[i], i == len(tokens) - 1)
    var decoder = RuneStreamDecoder()
    var text = String("")
    for _ in range(48):
        if next_token == 106 or next_token == 1:
            break
        ids.append(next_token)
        var spelling = session.tokenizer.vocabulary.vocab[next_token].replace("▁", " ")
        text += decoder.decode_token(spelling)
        next_token = session.forward(next_token)
    text += decoder.flush()
    return text


def run_case(mut session: Gemma4CUDASession, tokens: List[Int], span_mode: Int,
             span_start: Int, n_soft: Int, marker: Int,
             rows: List[Float32], mut ids: List[Int]) raises -> String:
    # span_mode: 0 = no span, 1 = control span, 2 = encoder rows span.
    # One session serves every case, reset() between them: a second
    # live Gemma4CUDASession in one process deadlocks inside the MAX
    # runtime during init (observed 2026-10-28: futex wait, GPU idle).
    if span_mode == 1:
        session.set_control_span(span_start, n_soft, marker)
    elif span_mode == 2:
        session.set_image_span(span_start, rows)
    var text = run_turn(session, tokens, ids)
    session.reset()
    return text


def main() raises:
    var args = argv()
    if len(args) < 5:
        raise Error("usage: image_chat_cuda_mmproj <model.gguf> <mmproj.gguf> <red.ppm> <blue.ppm>")
    var model_path = String(args[1])
    var mmproj_path = String(args[2])
    # Encoder rows first; count verification happens once the LM
    # width is known from a live session.
    var rows_red = encode_image_rows(mmproj_path, String(args[3]))
    var rows_blue = encode_image_rows(mmproj_path, String(args[4]))
    print("encoder rows (floats): red", len(rows_red), "blue", len(rows_blue))
    var session = Gemma4CUDASession(model_path)
    var width = session.profile.hidden_size
    var marker = session.tokenizer.control("<|image|>")
    print("marker id:", marker, "lm hidden:", width)
    if width <= 0 or len(rows_red) % width != 0 or len(rows_blue) % width != 0:
        raise Error("encoder rows do not divide by the LM hidden size")
    var n_soft = len(rows_red) // width
    if n_soft < 1 or len(rows_blue) // width != n_soft:
        raise Error("red/blue encoder row counts differ or are empty")
    print("encoder soft rows per image:", n_soft)
    var img_tokens = List[Int]()
    var span_start = build_tokens(session, True, n_soft, img_tokens)
    print("image prompt tokens:", img_tokens)
    print("span start:", span_start)
    if span_start < 0:
        raise Error("image prompt carries no marker span")
    var txt_tokens = List[Int]()
    _ = build_tokens(session, False, n_soft, txt_tokens)
    print("text prompt tokens:", txt_tokens)
    var empty = List[Float32]()
    # Section A: forward control.
    var ids_plain = List[Int]()
    var text_plain = run_case(session, img_tokens, 0, span_start,
                               n_soft, marker, empty, ids_plain)
    print("A plain ids:", ids_plain)
    print("A plain text:", text_plain)
    var ids_ctl = List[Int]()
    var text_ctl = run_case(session, img_tokens, 1, span_start,
                             n_soft, marker, empty, ids_ctl)
    print("A control ids:", ids_ctl)
    print("A control text:", text_ctl)
    var gate_a = len(ids_plain) == len(ids_ctl)
    if gate_a:
        for i in range(len(ids_plain)):
            if ids_plain[i] != ids_ctl[i]:
                gate_a = False
                break
    print("image chat forward control (CUDA):", "PASS" if gate_a else "FAIL")
    # Section B: behaviour with the real encoder rows.
    var ids_red = List[Int]()
    var text_red = run_case(session, img_tokens, 2, span_start,
                             n_soft, marker, rows_red, ids_red)
    print("RED IMAGE ANSWER:", text_red)
    print("red ids:", ids_red)
    var ids_blue = List[Int]()
    var text_blue = run_case(session, img_tokens, 2, span_start,
                              n_soft, marker, rows_blue, ids_blue)
    print("BLUE IMAGE ANSWER:", text_blue)
    print("blue ids:", ids_blue)
    var gate_b = contains_word(text_red, "red") and contains_word(text_blue, "blue") and text_red != text_blue
    print("image chat behaviour (CUDA):", "PASS" if gate_b else "FAIL")
    # Section C: text-only control.
    var ids_txt = List[Int]()
    var text_only = run_case(session, txt_tokens, 0, -1,
                              n_soft, marker, empty, ids_txt)
    print("TEXT-ONLY ANSWER:", text_only)
    print("text-only ids:", ids_txt)
    if not gate_a:
        raise Error("gate A failed: control span does not reproduce the plain run")
    if not gate_b:
        raise Error("gate B failed: answers do not track the images")
    print("image_chat_cuda_mmproj: DONE")
