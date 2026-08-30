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

    var empty_param_rejected = False
    try:
        _ = HuggingFaceSeer.build_download_url("", "smollm-360m.gguf")
    except:
        empty_param_rejected = True
    if not empty_param_rejected:
        print("FAIL: build_download_url failed to reject empty repo_id")
        success = False

    if success:
        print("HuggingFace CDN URL Builder: PASS")
    else:
        raise Error("Hugging Face URL builder invariant mismatch")


def test_hf_mobile_model_download() raises:
    print("--- Testing Hugging Face model download functionality ---")
    var seer = HuggingFaceSeer()
    var url = HuggingFaceSeer.build_download_url("hf.co/HuggingFaceTB/SmolLM-135M", "model.gguf")
    if "https://huggingface.co/HuggingFaceTB/SmolLM-135M/resolve/main/model.gguf" not in url:
        raise Error("Hugging Face download URL builder mismatch")
    
    var empty_param_rejected = False
    try:
        _ = seer.download_hf_model("", "model.gguf")
    except error:
        empty_param_rejected = True
    if not empty_param_rejected:
        raise Error("Hugging Face downloader allowed empty repo_id")

    print("Hugging Face model download functionality: PASS")
