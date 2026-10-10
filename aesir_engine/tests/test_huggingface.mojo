# tests/test_huggingface.mojo
# Verification of Hugging Face string helpers and unsupported download boundary

from std.ffi import external_call
from loader.huggingface import (
    HuggingFaceSeer,
    _hf_cstring,
    _hf_run_checked,
    _hf_verify_complete_download,
)
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

    if not HuggingFaceSeer.is_hf_tag("https://huggingface.co/org/repo"):
        print("FAIL: is_hf_tag HTTPS repository check failed")
        success = False

    var invalid_tags: List[String] = [
        "", "http://example.com/org/repo", "https://example.com/org/repo",
        "org/repo/extra", "org//repo", "../repo", "org/repo?download=1",
        "single-name",
    ]
    for tag in invalid_tags:
        if HuggingFaceSeer.is_hf_tag(tag):
            print("FAIL: is_hf_tag accepted invalid repository identity: " + tag)
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


def test_hf_download_parameter_boundary() raises:
    print("--- Testing Hugging Face download parameter boundary ---")
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

    print("Hugging Face download parameter boundary: PASS")


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


def _hf_test_pwrite_all(fd: Int32, data: List[Byte], offset: Int) raises:
    var done = 0
    while done < len(data):
        var count = external_call["pwrite", Int](
            fd, data.unsafe_ptr().unsafe_offset(done), len(data) - done,
            Int64(offset + done),
        )
        if count <= 0:
            raise Error("Hugging Face test staging write failed")
        done += count


def test_hf_resume_completion_verification() raises:
    print("--- Testing Hugging Face resume-path completion verification (F011) ---")
    var template = _hf_cstring("/tmp/aesir-hf-resume-test-XXXXXX")
    var fd = external_call["mkstemp", Int32](template.unsafe_ptr())
    if fd < 0:
        raise Error("Hugging Face test staging file creation failed")
    var path = String(unsafe_from_utf8_ptr=template.unsafe_ptr())
    try:
        # 64-byte pinned GGUF v3 artifact (downloader requires >= 24 bytes).
        var payload = List[Byte]()
        var magic: List[Int] = [71, 71, 85, 70, 3, 0, 0, 0]
        for byte in magic:
            payload.append(Byte(byte))
        for i in range(56):
            payload.append(Byte((i * 37 + 11) % 251))
        # Simulate an interrupted download: stage the first 40 bytes, then
        # "resume" by appending the remainder, exactly as curl --continue-at
        # would leave the staging descriptor.
        var first = List[Byte]()
        for i in range(40):
            first.append(payload[i])
        _hf_test_pwrite_all(fd, first, 0)
        var rest = List[Byte]()
        for i in range(40, 64):
            rest.append(payload[i])
        _hf_test_pwrite_all(fd, rest, 40)
        var argv: List[String] = ["sha256sum", "--", path]
        var digest = _hf_run_checked(argv)
        var sha = String(digest[byte=0:64])
        # The resumed completion must verify exactly like a fresh download.
        _hf_verify_complete_download(fd, 64, sha)

        # Tamper one byte: fail-closed SHA-256 rejection.
        var flip = List[Byte]()
        flip.append(payload[8] ^ 255)
        _hf_test_pwrite_all(fd, flip, 8)
        var tamper_rejected = False
        try:
            _hf_verify_complete_download(fd, 64, sha)
        except error:
            tamper_rejected = "SHA-256 mismatch" in String(error)
        if not tamper_rejected:
            raise Error("Tampered staged download was not rejected")

        # Restore the byte, then a wrong pinned size must fail closed.
        var original = List[Byte]()
        original.append(payload[8])
        _hf_test_pwrite_all(fd, original, 8)
        var size_rejected = False
        try:
            _hf_verify_complete_download(fd, 63, sha)
        except error:
            size_rejected = "size mismatch" in String(error)
        if not size_rejected:
            raise Error("Wrong-size staged download was not rejected")

        # A non-GGUF magic must fail closed even at the pinned size.
        var bad = List[Byte]()
        for _ in range(64):
            bad.append(Byte(0))
        _hf_test_pwrite_all(fd, bad, 0)
        var bad_argv: List[String] = ["sha256sum", "--", path]
        var bad_digest = _hf_run_checked(bad_argv)
        var bad_sha = String(bad_digest[byte=0:64])
        var header_rejected = False
        try:
            _hf_verify_complete_download(fd, 64, bad_sha)
        except error:
            header_rejected = "not GGUF v3" in String(error)
        if not header_rejected:
            raise Error("Non-GGUF staged download was not rejected")
    except error:
        _ = external_call["close", Int32](fd)
        _ = external_call["unlink", Int32](template.unsafe_ptr())
        raise error
    _ = external_call["close", Int32](fd)
    _ = external_call["unlink", Int32](template.unsafe_ptr())
    print("Hugging Face resume completion verification: PASS")
