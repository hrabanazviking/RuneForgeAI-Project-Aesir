# tests/test_huggingface.mojo
# Verification of HuggingFace Hub Integration & Mobile Model Downloader (Slice 13)

from loader.huggingface import HuggingFaceSeer
from cli.manifest import RuneModelStore

def test_hf_repo_parsing():
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

    if success:
        print("HuggingFace Tag Parsing: PASS")
    else:
        print("HuggingFace Tag Parsing: FAIL")


def test_hf_download_url_builder():
    print("--- Testing HuggingFace CDN Download URL Builder ---")
    var success = True
    var url = HuggingFaceSeer.build_download_url("hf.co/HuggingFaceTB/SmolLM-360M-Instruct-GGUF", "smollm-360m.gguf")

    if url != "https://huggingface.co/HuggingFaceTB/SmolLM-360M-Instruct-GGUF/resolve/main/smollm-360m.gguf":
        print("FAIL: CDN Download URL mismatch:", url)
        success = False

    if success:
        print("HuggingFace CDN URL Builder: PASS")
    else:
        print("HuggingFace CDN URL Builder: FAIL")


def test_hf_mobile_model_download() raises:
    print("--- Testing HuggingFace Mobile/Edge Model Downloader ---")
    var success = True
    var seer = HuggingFaceSeer()
    var store = RuneModelStore()

    if not seer.download_hf_model("hf.co/HuggingFaceTB/SmolLM-135M", "model.gguf"):
        print("FAIL: HuggingFace mobile model download stream failed")
        success = False
    else:
        var norm_repo = HuggingFaceSeer.parse_hf_repo("hf.co/HuggingFaceTB/SmolLM-135M")
        var sample_modelfile = String("FROM model.gguf\nSYSTEM HuggingFace Model")
        store.create_model(norm_repo, sample_modelfile)
        print("HuggingFace Model registered successfully in RuneModelStore catalog.")

    if success:
        print("HuggingFace Mobile Model Downloader: PASS")
    else:
        print("HuggingFace Mobile Model Downloader: FAIL")
