# tests/test_huggingface.mojo
# Verification of Hugging Face string helpers and unsupported download boundary

from loader.huggingface import HuggingFaceSeer

def test_hf_repo_parsing() raises:
    print("--- Testing HuggingFaceSeer Repo Tag Parsing ---")
    var success = True

    if HuggingFaceSeer.parse_hf_repo("hf.co/HuggingFaceTB/SmolLM-360M-Instruct-GGUF") != "HuggingFaceTB/SmolLM-360M-Instruct-GGUF":
        print("FAIL: hf.co prefix parsing failed")
        success = False

    if HuggingFaceSeer.parse_hf_repo("huggingface.co/meta-llama/Llama-3.2-1B-Instruct") != "meta-llama/Llama-3.2-1B-Instruct":
        print("FAIL: huggingface.co prefix parsing failed")
        success = False

    if not HuggingFaceSeer.is_hf_tag("hf.co/org/repo"):
        print("FAIL: is_hf_tag hf.co check failed")
        success = False

    if not HuggingFaceSeer.is_hf_tag("org/repo"):
        print("FAIL: is_hf_tag org/repo check failed")
        success = False

    if HuggingFaceSeer.is_hf_tag(""):
        print("FAIL: is_hf_tag empty string check failed")
        success = False

    if success:
        print("HuggingFace Tag Parsing: PASS")
    else:
        raise Error("Hugging Face tag parsing invariant mismatch")


def test_hf_download_url_builder() raises:
    print("--- Testing HuggingFace CDN Download URL Builder ---")
    var success = True
    var url = HuggingFaceSeer.build_download_url("hf.co/HuggingFaceTB/SmolLM-360M-Instruct-GGUF", "smollm-360m.gguf")

    if url != "https://huggingface.co/HuggingFaceTB/SmolLM-360M-Instruct-GGUF/resolve/main/smollm-360m.gguf":
        print("FAIL: CDN Download URL mismatch:", url)
        success = False

    if success:
        print("HuggingFace CDN URL Builder: PASS")
    else:
        raise Error("Hugging Face URL builder invariant mismatch")


def test_hf_mobile_model_download() raises:
    print("--- Testing unsupported Hugging Face download boundary ---")
    var seer = HuggingFaceSeer()
    var rejected = False
    try:
        _ = seer.download_hf_model(
            "hf.co/HuggingFaceTB/SmolLM-135M", "model.gguf"
        )
    except error:
        rejected = True
        if "not implemented" not in String(error):
            raise Error("Hugging Face rejection omitted stable truth text")
    if not rejected:
        raise Error("Hugging Face downloader returned fabricated success")
    print("unsupported Hugging Face download boundary: PASS")
