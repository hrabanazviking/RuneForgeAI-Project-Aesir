# tests/test_huggingface.mojo
# Verification of Hugging Face string helpers and unsupported download boundary

from loader.huggingface import HuggingFaceSeer, _hf_run_checked
from cli.commands import dispatch_pull

def test_hf_repo_parsing() raises:
    print("--- Testing HuggingFaceSeer Repo Tag Parsing ---")
    var success = True
    if HuggingFaceSeer.parse_hf_repo("https://huggingface.co/org/repo") != "org/repo":
        raise Error("HTTPS repository normalization failed")
    if HuggingFaceSeer.parse_hf_repo("https://hf.co/org/repo") != "org/repo":
        raise Error("HTTPS short repository normalization failed")

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
    var invalid: List[String] = ["../model.gguf", "a/../model.gguf", "x?download=1",
                                 "$(touch injected)", "a//b.gguf"]
    for filename in invalid:
        var rejected = False
        try:
            _ = HuggingFaceSeer.build_download_url("org/repo", filename)
        except error:
            rejected = "Hugging Face" in String(error)
        if not rejected:
            raise Error("Unsafe Hub filename was accepted")
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


def test_hf_subprocess_argument_safety() raises:
    var payload = String("$(printf INJECTED); `printf BAD`; quotes: \" '")
    var args: List[String] = ["printf", "%s", payload]
    if _hf_run_checked(args) != payload:
        raise Error("Subprocess interpreted literal argument text")
    var failed = False
    try:
        var failing: List[String] = ["false"]
        _ = _hf_run_checked(failing)
    except error:
        failed = "subprocess failed" in String(error)
    if not failed:
        raise Error("Nonzero subprocess result did not fail closed")


def test_hf_pinned_download_admission() raises:
    var hf = HuggingFaceSeer()
    var rejected = False
    try:
        _ = hf.download_hf_model("org/repo", "model.gguf")
    except error:
        rejected = "revision" in String(error)
    if not rejected:
        raise Error("Unpinned download reached external I/O")
    var cases: List[List[String]] = [
        ["pull", "org/repo"],
        ["pull", "org/repo", "model.gguf", "--insecure"],
        ["pull", "org/repo", "model.gguf", "--size", "9223372036854775808"],
        ["pull", "org/repo", "model.gguf", "--size", "-1"],
        ["pull", "org/repo", "model.gguf", "--revision"],
        ["pull", "org/repo", "model.gguf", "--size", "24", "--size", "25"],
    ]
    for args in cases:
        var failed = False
        try:
            dispatch_pull(args)
        except error:
            failed = "pull" in String(error)
        if not failed:
            raise Error("Invalid pull arguments were not rejected before I/O")
