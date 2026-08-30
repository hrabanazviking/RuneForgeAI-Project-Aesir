# loader/huggingface.mojo
# HuggingFaceSeer: repository tag and resolve-URL helpers

from std.ffi import external_call

struct HuggingFaceSeer:
    """
    ᚺᛢᚷᚷᛁ᛾ᚷ·ᚠᚨᚲᛖ·ᛋᛖᛖᚱ — The Vision of the HuggingFace Hub (HuggingFaceSeer)
    ══════════════════════════════════════════════════════════════════════════
    Repository tag normalization and resolve-URL construction for Hugging Face.
    Parses HuggingFace repository tags (hf.co/org/model, huggingface.co/org/model, org/repo),
    Model downloading is not implemented.
    """
    var default_cdn: String

    def __init__(out self):
        self.default_cdn = "https://huggingface.co"

    @staticmethod
    def parse_hf_repo(model_tag: String) -> String:
        """
        ᛈᚨᚱᛋᛖ·ᚺᚠ·ᚱᛖᛈᛟ — The Repository Normalization Rune (parse_hf_repo)
        ══════════════════════════════════════════════════════════════════════════
        Normalizes HuggingFace repository URI strings into canonical org/repo runes.
        Strips 'hf.co/' and 'huggingface.co/' prefixes to resolve raw repository identifiers.
        e.g., 'hf.co/HuggingFaceTB/SmolLM-360M-Instruct-GGUF' -> 'HuggingFaceTB/SmolLM-360M-Instruct-GGUF'
        'huggingface.co/meta-llama/Llama-3.2-1B-Instruct' -> 'meta-llama/Llama-3.2-1B-Instruct'
        """
        var tag = model_tag
        if tag.startswith("hf.co/"):
            return String(tag[byte=6:len(tag.bytes())])
        elif tag.startswith("huggingface.co/"):
            return String(tag[byte=15:len(tag.bytes())])
        return tag

    @staticmethod
    def is_hf_tag(model_tag: String) -> Bool:
        """
        ᛁᛋ·ᚺᚠ·ᛏᚨᚷ — The Realm Discriminant Rune (is_hf_tag)
        ══════════════════════════════════════════════════════════════════════════
        Determines whether a model tag points to the HuggingFace Hub repository realm
        by inspecting URI prefixes ('hf.co/', 'huggingface.co/') or 'org/repo' namespace patterns.
        """
        if len(model_tag.bytes()) == 0:
            return False
        if model_tag.startswith("hf.co/") or model_tag.startswith("huggingface.co/"):
            return True
        # Check for org/repo pattern
        if "/" in model_tag and not model_tag.endswith(".gguf"):
            return True
        return False

    @staticmethod
    def build_download_url(repo_id: String, filename: String = "model.gguf") raises -> String:
        """
        ᛒᛢᛁᛚᛞ·ᛞᛟᚹᚾᛚᛟᚨᛞ·ᛢᚱᛚ — The Bifrost Stream URL Builder (build_download_url)
        ══════════════════════════════════════════════════════════════════════════
        Constructs direct HuggingFace resolve CDN download URLs for GGUF model files.
        Maps repository identifiers and target filenames into high-throughput HTTPS weight streams.
        """
        if len(repo_id.bytes()) == 0 or len(filename.bytes()) == 0:
            raise Error("HuggingFaceSeer.build_download_url: repo_id and filename must not be empty")
        var norm_repo = HuggingFaceSeer.parse_hf_repo(repo_id)
        var res = String("https://huggingface.co/")
        res += norm_repo
        res += String("/resolve/main/")
        res += filename
        return res

    def download_hf_model(self, repo_id: String, filename: String, dest_path: String = "") raises -> Bool:
        """
        ᛞᛟᚹᚾᛚᛟᚨᛞ·ᚺᚠ·ᛗᛟᛞᛖᛚ — The Stream Downloader & Weight Inscription (download_hf_model)
        ══════════════════════════════════════════════════════════════════════════
        Downloads GGUF weights directly from HuggingFace CDN to dest_path via HTTPS stream.
        """
        if len(repo_id.bytes()) == 0 or len(filename.bytes()) == 0:
            raise Error("HuggingFaceSeer.download_hf_model: repo_id and filename must not be empty")
        var url = HuggingFaceSeer.build_download_url(repo_id, filename)
        var out_file = dest_path
        if len(out_file.bytes()) == 0:
            out_file = filename

        var cmd = String("curl -sSL -f \"") + url + String("\" -o \"") + out_file + String("\"")
        var cmd_bytes = cmd.as_bytes()
        var ret = external_call["system", Int32](cmd_bytes.unsafe_ptr().unsafe_bitcast[Int8]())
        _ = cmd_bytes
        if ret != 0:
            raise Error("Failed to download model from Hugging Face: " + url)
        return True
