"""Generate test-only Llama 3 token-ID expectations from the pinned HF file."""
import argparse
import hashlib
import json
from pathlib import Path
import tokenizers


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("tokenizer", type=Path)
    p.add_argument("output", type=Path)
    args = p.parse_args()
    tokenizer = tokenizers.Tokenizer.from_file(str(args.tokenizer))
    texts = [
        "Hello, captain! The lighthouse is awake.",
        "I'm sure she'll say WE'RE late, but I can't stop.",
        "   One  two\tthree\n\nFour!\r\n  ",
        "Numbers: 1234567890; 3.14159; Ⅳ ² ١٢٣٤.",
        "Sigrún says: café, naïve, déjà vu. 日本語 😀",
        "\u00a0oak\u2003leaf\u2028sea\u3000salt",
        "a\u0301 b\u0327 \r\n\t", "", " ", "\n\n",
        "<|start_header_id|>user<|end_header_id|> is literal text.",
        "?hello!world:: lighthouse---keeper 0000",
    ]
    # Plain text is not allowed to inject special controls. Remove the added
    # token recognizer for these reference cases, retaining BPE/postprocessor.
    data = json.loads(args.tokenizer.read_text(encoding="utf-8"))
    data["added_tokens"] = []
    plain = tokenizers.Tokenizer.from_str(json.dumps(data))
    fixture = {"source": "Sao10K/L3-8B-Stheno-v3.2", "revision": "4bb828f6e1b1efd648c39b1ad682c44ff260f018", "tokenizer_sha256": hashlib.sha256(args.tokenizer.read_bytes()).hexdigest(), "tool": "tokenizers==" + tokenizers.__version__, "cases": []}
    for text in texts:
        ids = [128000] + plain.encode(text, add_special_tokens=False).ids
        fixture["cases"].append({"text": text, "ids": ids})
    messages = "<|begin_of_text|><|start_header_id|>system<|end_header_id|>\n\nYou are a captain.<|eot_id|><|start_header_id|>user<|end_header_id|>\n\nHello.<|eot_id|><|start_header_id|>assistant<|end_header_id|>\n\n"
    fixture["chat_ids"] = tokenizer.encode(messages, add_special_tokens=False).ids
    args.output.write_text(json.dumps(fixture, ensure_ascii=False, indent=2) + "\n", encoding="utf-8", newline="\n")
    print(f"Generated {len(texts)} independent tokenizer cases")


if __name__ == "__main__":
    main()
