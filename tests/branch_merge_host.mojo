# Merge regression: host text and tool descriptors only; no model execution.
from tests.test_tokenizer import test_tokenizer, test_stream_decoder, test_multilingual_corpora, test_validate_vocabulary_duplicate_spelling, test_validate_vocabulary_missing_coverage, test_validate_vocabulary_empty_special_spelling, test_add_token_negative_id, test_encode_special_token_resolution, test_decode_token_invalid_hex, test_stream_decoder_invalid_byte_replacement, test_byte_bpe_merge_baseline, test_byte_bpe_merge_interface, test_byte_bpe_merge_adversarial, test_byte_bpe_merge_integration, test_byte_bpe_merge_negative_scores, test_unicode_normalization_baseline, test_unicode_normalization_interface, test_unicode_normalization_integration, test_unicode_normalization_adversarial, test_invalid_utf8_rejection, test_invalid_utf8_adversarial, test_invalid_utf8_integration, test_invalid_utf8_single_byte_sweep
from loader.corpus_ingestion import chunk_text
from core.tool_use import ToolDefinition, ToolCall, resolve_allowlisted_tool, validate_gemma_zero_arg_tool, parse_gemma_zero_arg_call

def main() raises:
    test_tokenizer()
    test_stream_decoder()
    test_multilingual_corpora()
    test_validate_vocabulary_duplicate_spelling()
    test_validate_vocabulary_missing_coverage()
    test_validate_vocabulary_empty_special_spelling()
    test_add_token_negative_id()
    test_encode_special_token_resolution()
    test_decode_token_invalid_hex()
    test_stream_decoder_invalid_byte_replacement()
    test_byte_bpe_merge_baseline()
    test_byte_bpe_merge_interface()
    test_byte_bpe_merge_adversarial()
    test_byte_bpe_merge_integration()
    test_byte_bpe_merge_negative_scores()
    test_unicode_normalization_baseline()
    test_unicode_normalization_interface()
    test_unicode_normalization_integration()
    test_unicode_normalization_adversarial()
    test_invalid_utf8_rejection()
    test_invalid_utf8_adversarial()
    test_invalid_utf8_integration()
    test_invalid_utf8_single_byte_sweep()
    var texts = List[String]()
    texts.append("abcdef")
    texts.append("éab😀z")
    texts.append("á🌋界")
    for text in texts:
        for size in range(1, 10):
            var chunks = chunk_text(text, size, 0)
            var restored = String("")
            var offset = 0
            for chunk in chunks:
                if chunk.byte_offset != offset:
                    raise Error("merge: UTF-8 chunks skipped or repeated bytes")
                restored += chunk.text
                offset += chunk.text.byte_length()
            if restored != text:
                raise Error("merge: UTF-8 round trip failed")
    validate_gemma_zero_arg_tool("clock", "Read the clock")
    var call = parse_gemma_zero_arg_call("<|tool_call>call:clock{}<tool_call|>", "clock")
    var tools = List[ToolDefinition]()
    tools.append(ToolDefinition("clock", "Read the clock", "{\"type\":\"object\"}"))
    var selected = resolve_allowlisted_tool(call, tools)
    if selected.name != "clock":
        raise Error("merge: tool allowlist resolution failed")
    print("MERGE-HOST-PASS")
