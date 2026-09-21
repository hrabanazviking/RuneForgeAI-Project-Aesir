# loader/huggingface.mojo
# HuggingFaceSeer: repository tag and resolve-URL helpers

from std.ffi import external_call
from std.memory import Pointer
from std.collections import InlineArray


def _hf_cstring(value: String) raises -> List[Int8]:
    var result = List[Int8]()
    for byte in value.as_bytes():
        if byte == 0:
            raise Error("Hugging Face argument contains NUL")
        result.append(Int8(byte))
    result.append(0)
    return result^


def _hf_run_checked(args: List[String]) raises -> String:
    """Run an argv vector on POSIX, without a shell, and check child completion.

    Buffers are owned before fork; the child only closes/duplicates descriptors,
    execs, or exits. Small stdout is captured; stderr remains visible to callers.
    """
    if len(args) == 0:
        raise Error("Hugging Face subprocess requires an executable")
    var buffers = List[List[Int8]]()
    for arg in args:
        buffers.append(_hf_cstring(arg))
    # Linux pointer-width slots express execvp's nullable char* argv ABI.
    # Mojo Pointer itself is non-nullable; the final C slot must be zero.
    var pointers = List[Int]()
    for i in range(len(buffers)):
        pointers.append(Int(buffers[i].unsafe_ptr()))
    pointers.append(0)
    var program = pointers[0]
    var descriptors: List[Int32] = [0, 0]
    if external_call["pipe", Int32](descriptors.unsafe_ptr()) != 0:
        raise Error("Hugging Face subprocess pipe failed")
    var pid = external_call["fork", Int32]()
    if pid == 0:
        _ = external_call["close", Int32](descriptors[0])
        if external_call["dup2", Int32](descriptors[1], Int32(1)) < 0:
            external_call["_exit", NoneType](Int32(126))
        _ = external_call["close", Int32](descriptors[1])
        _ = external_call["execvp", Int32](program, pointers.unsafe_ptr())
        _ = buffers
        external_call["_exit", NoneType](Int32(127))
    _ = external_call["close", Int32](descriptors[1])
    if pid < 0:
        _ = external_call["close", Int32](descriptors[0])
        raise Error("Hugging Face subprocess creation failed")
    var output = List[Byte]()
    var chunk = List[Byte]()
    chunk.resize(4096, 0)
    var read_failed = False
    while True:
        # Match std.io's Mojo 1.0 read declaration (Int fd/length/result).
        var count = external_call["read", Int](
            Int(descriptors[0]), chunk.unsafe_ptr(), Int(4096)
        )
        if count == 0:
            break
        if count < 0:
            var errno_ptr = external_call[
                "__errno_location", Pointer[Int32, MutUntrackedOrigin]
            ]()
            if errno_ptr.unsafe_load() == 4:  # POSIX EINTR
                continue
            read_failed = True
            break
        if len(output) + count <= 16384:
            for i in range(count):
                output.append(chunk[i])
        else:
            # Keep draining so the child cannot deadlock on a full pipe.
            read_failed = True
    _ = external_call["close", Int32](descriptors[0])
    var status: Int32 = 0
    var waited: Int32 = -1
    while waited < 0:
        waited = external_call["waitpid", Int32](pid, Pointer(to=status), Int32(0))
        if waited < 0:
            var errno_ptr = external_call[
                "__errno_location", Pointer[Int32, MutUntrackedOrigin]
            ]()
            if errno_ptr.unsafe_load() != 4:
                raise Error("Hugging Face subprocess wait failed")
    _ = buffers
    if status != 0:
        raise Error("Hugging Face subprocess failed: " + args[0]
                    + " (wait status " + String(status) + ")")
    if read_failed:
        raise Error("Hugging Face subprocess output invalid or too large")
    output.append(0)
    return String(unsafe_from_utf8_ptr=output.unsafe_ptr())


def _hf_validate_path(value: String, label: String) raises:
    """Admit safe Hub path segments; reject URL/query/path traversal syntax."""
    if len(value.bytes()) == 0:
        raise Error("Hugging Face " + label + " must not be empty")
    for part in value.split("/"):
        if part == "" or part == "." or part == "..":
            raise Error("Hugging Face " + label + " contains an invalid segment")
    for byte in value.as_bytes():
        if not ((byte >= 48 and byte <= 57) or (byte >= 65 and byte <= 90)
                or (byte >= 97 and byte <= 122) or byte == 45 or byte == 46
                or byte == 95 or byte == 47):
            raise Error("Hugging Face " + label + " contains unsupported characters")


def _hf_validate_hex(value: String, length: Int, label: String) raises:
    if len(value.bytes()) != length:
        raise Error("Hugging Face " + label + " has invalid length")
    for byte in value.as_bytes():
        if not ((byte >= 48 and byte <= 57) or (byte >= 97 and byte <= 102)):
            raise Error("Hugging Face " + label + " must be lowercase hexadecimal")


def _hf_errno() -> Int32:
    return external_call[
        "__errno_location", Pointer[Int32, MutUntrackedOrigin]
    ]().unsafe_load()


def _hf_parent_path(path: String) -> String:
    var last_slash = -1
    for index in range(len(path.bytes())):
        if path.as_bytes()[index] == 47:
            last_slash = index
    if last_slash < 0:
        return "."
    if last_slash == 0:
        return "/"
    return String(path[byte=0:last_slash])


def _hf_filename(path: String) raises -> String:
    if len(path.bytes()) == 0 or len(path.bytes()) >= 4096 or "\0" in path:
        raise Error("Hugging Face output path must contain 1..4095 non-NUL bytes")
    var last_slash = -1
    for index in range(len(path.bytes())):
        if path.as_bytes()[index] == 47:
            last_slash = index
    var name = path if last_slash < 0 else String(path[byte=last_slash + 1:])
    if name == "" or name == "." or name == "..":
        raise Error("Hugging Face output filename is invalid")
    return name


def _hf_same_inode(
    directory_fd: Int32, name: List[Int8], device: UInt64, inode: UInt64,
) -> Bool:
    var stat = InlineArray[UInt64, 18](fill=0)
    # AT_SYMLINK_NOFOLLOW: a replacement symlink must never compare equal.
    if external_call["fstatat", Int32](
        directory_fd, name.unsafe_ptr(), stat.unsafe_ptr(), Int32(256)
    ) != 0:
        return False
    return stat[0] == device and stat[1] == inode and stat[3] & 61440 == 32768


def _hf_unlink_stage_if_same(
    directory_fd: Int32, name: List[Int8], device: UInt64, inode: UInt64,
) -> Int32:
    """Return 1 when removed, 0 when replaced/missing, and -1 on unlink error."""
    if not _hf_same_inode(directory_fd, name, device, inode):
        return 0
    if external_call["unlinkat", Int32](
        directory_fd, name.unsafe_ptr(), Int32(0)
    ) != 0:
        return -1
    return 1


def _hf_run_with_open_fd(var args: List[String], fd: Int32) raises -> String:
    """Expose one exact open inode to a checked child through inherited procfs."""
    var inherited_fd = external_call["dup", Int32](fd)
    if inherited_fd < 0:
        raise Error("Hugging Face cannot inherit staging descriptor")
    args.append("/proc/self/fd/" + String(inherited_fd))
    try:
        var result = _hf_run_checked(args)
        _ = external_call["close", Int32](inherited_fd)
        return result^
    except error:
        _ = external_call["close", Int32](inherited_fd)
        raise error


def _hf_transfer(
    url: String, path: String, fd: Int32, expected_size: Int, connections: Int,
) raises:
    """Transfer bounded HTTPS ranges, assemble locally, and release owned parts.

    Each range must have exactly the requested byte length. Servers ignoring
    Range fail closed. The caller verifies the complete file's SHA-256.
    """
    var part_fds = List[Int32]()
    var inherited_fds = List[Int32]()
    var part_sizes = List[Int]()
    var args: List[String] = ["curl", "-q", "--parallel", "--parallel-immediate",
                              "--parallel-max", String(connections), "--fail-early"]
    var cursor = 0
    try:
        for index in range(connections):
            var size = expected_size // connections
            if index < expected_size % connections:
                size += 1
            var part = _hf_cstring(path + ".range.XXXXXX")
            var part_fd = external_call["mkstemp", Int32](part.unsafe_ptr())
            if part_fd < 0:
                raise Error("Hugging Face range staging creation failed")
            # Range mode is not resumable. Remove every temporary pathname
            # before curl starts and expose only the inherited exact inode.
            if external_call["unlink", Int32](part.unsafe_ptr()) != 0:
                _ = external_call["close", Int32](part_fd)
                raise Error("Hugging Face range staging unlink failed")
            var inherited_fd = external_call["dup", Int32](part_fd)
            if inherited_fd < 0:
                _ = external_call["close", Int32](part_fd)
                raise Error("Hugging Face range descriptor inheritance failed")
            part_fds.append(part_fd)
            inherited_fds.append(inherited_fd)
            part_sizes.append(size)
            if index > 0:
                args.append("--next")
            var transfer_args: List[String] = [
                "--fail", "--location", "--silent", "--show-error",
                "--proto", "=https", "--proto-redir", "=https",
                "--connect-timeout", "30", "--max-time", "7200",
                "--speed-limit", "1024", "--speed-time", "120",
                "--max-filesize", String(size), "--output",
                "/proc/self/fd/" + String(inherited_fd),
                "--range", String(cursor) + "-" + String(cursor + size - 1),
                "--url", url,
            ]
            for arg in transfer_args:
                args.append(arg)
            cursor += size
        _ = _hf_run_checked(args)
        for inherited_fd in inherited_fds:
            _ = external_call["close", Int32](inherited_fd)
        inherited_fds = List[Int32]()
        for index in range(connections):
            var part_fd = part_fds[index]
            var actual_size = external_call["lseek", Int64](part_fd, Int64(0), Int32(2))
            if actual_size != Int64(part_sizes[index]):
                raise Error("Hugging Face downloaded range size mismatch")
            _ = external_call["lseek", Int64](part_fd, Int64(0), Int32(0))
            var remaining = part_sizes[index]
            while remaining > 0:
                var copied = external_call["sendfile", Int](
                    fd, part_fd, Int(0), min(remaining, 1048576)
                )
                if copied < 0:
                    var errno_ptr = external_call["__errno_location", Pointer[Int32, MutUntrackedOrigin]]()
                    if errno_ptr.unsafe_load() == 4:
                        continue
                if copied <= 0:
                    raise Error("Hugging Face range assembly failed")
                remaining -= copied
    except error:
        for inherited_fd in inherited_fds:
            _ = external_call["close", Int32](inherited_fd)
        for index in range(len(part_fds)):
            _ = external_call["close", Int32](part_fds[index])
        raise error
    var cleanup_failed = False
    for index in range(len(part_fds)):
        if external_call["close", Int32](part_fds[index]) != 0:
            cleanup_failed = True
    if cleanup_failed:
        raise Error("Hugging Face range staging cleanup failed")

struct HuggingFaceSeer:
    """
    ᚺᛢᚷᚷᛁ᛾ᚷ·ᚠᚨᚲᛖ·ᛋᛖᛖᚱ — The Vision of the HuggingFace Hub (HuggingFaceSeer)
    ══════════════════════════════════════════════════════════════════════════
    Repository tag normalization and resolve-URL construction for Hugging Face.
    Parses HuggingFace repository tags (hf.co/org/model, huggingface.co/org/model, org/repo),
    Public GGUF downloads require a pinned revision, byte size and SHA-256.
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
        if tag.startswith("https://huggingface.co/"):
            return String(tag[byte=23:len(tag.bytes())])
        elif tag.startswith("https://hf.co/"):
            return String(tag[byte=14:len(tag.bytes())])
        elif tag.startswith("hf.co/"):
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
        if (
            "://" in model_tag
            and not model_tag.startswith("https://huggingface.co/")
            and not model_tag.startswith("https://hf.co/")
        ):
            return False
        var normalized = HuggingFaceSeer.parse_hf_repo(model_tag)
        try:
            _hf_validate_path(normalized, "repository")
        except:
            return False
        return len(normalized.split("/")) == 2

    @staticmethod
    def build_download_url(
        repo_id: String, filename: String = "model.gguf", revision: String = "main"
    ) raises -> String:
        """
        ᛒᛢᛁᛚᛞ·ᛞᛟᚹᚾᛚᛟᚨᛞ·ᛢᚱᛚ — The Bifrost Stream URL Builder (build_download_url)
        ══════════════════════════════════════════════════════════════════════════
        Constructs direct HuggingFace resolve CDN download URLs for GGUF model files.
        Maps repository identifiers and target filenames into high-throughput HTTPS weight streams.
        """
        if len(repo_id.bytes()) == 0 or len(filename.bytes()) == 0:
            raise Error("HuggingFaceSeer.build_download_url: repo_id and filename must not be empty")
        var norm_repo = HuggingFaceSeer.parse_hf_repo(repo_id)
        _hf_validate_path(norm_repo, "repository")
        if len(norm_repo.split("/")) != 2:
            raise Error("Hugging Face repository must be owner/name")
        _hf_validate_path(filename, "filename")
        _hf_validate_path(revision, "revision")
        var res = String("https://huggingface.co/")
        res += norm_repo
        res += String("/resolve/") + revision + "/"
        res += filename
        return res

    def download_hf_model(
        self, repo_id: String, filename: String, dest_path: String = "",
        revision: String = "", expected_sha256: String = "", expected_size: Int = 0,
        connections: Int = 1,
    ) raises -> Bool:
        """
        ᛞᛟᚹᚾᛚᛟᚨᛞ·ᚺᚠ·ᛗᛟᛞᛖᛚ — The Stream Downloader & Weight Inscription (download_hf_model)
        ══════════════════════════════════════════════════════════════════════════
        Download a public pinned GGUF, verify it, and atomically create dest_path.
        Requires system curl and sha256sum. Never overwrites an existing file.
        Single-connection transfers resume from a locked deterministic .part file.
        Completed bytes are still published only after size, header, and SHA-256 checks.
        """
        if len(repo_id.bytes()) == 0 or len(filename.bytes()) == 0:
            raise Error("HuggingFaceSeer.download_hf_model: repo_id and filename must not be empty")
        _hf_validate_hex(revision, 40, "revision")
        _hf_validate_hex(expected_sha256, 64, "SHA-256")
        if expected_size < 24:
            raise Error("Hugging Face expected size must include a GGUF v3 header")
        if connections < 1 or connections > 8:
            raise Error("Hugging Face connections must be between 1 and 8")
        if not filename.endswith(".gguf"):
            raise Error("Hugging Face downloader requires a .gguf filename")
        var url = HuggingFaceSeer.build_download_url(repo_id, filename, revision)
        var out_file = dest_path
        if len(out_file.bytes()) == 0:
            out_file = filename

        var target_name = _hf_filename(out_file)
        var parent_path = _hf_parent_path(out_file)
        var parent = _hf_cstring(parent_path)
        # O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC.
        var directory_fd = external_call["open64", Int32](
            parent.unsafe_ptr(), Int32(720896), Int32(0)
        )
        if directory_fd < 0:
            raise Error("Hugging Face output parent must be a safe directory")
        var target = _hf_cstring(target_name)
        var target_stat = InlineArray[UInt64, 18](fill=0)
        if external_call["fstatat", Int32](
            directory_fd, target.unsafe_ptr(), target_stat.unsafe_ptr(), Int32(256)
        ) == 0:
            _ = external_call["close", Int32](directory_fd)
            raise Error("Hugging Face cannot publish download; destination may exist")
        if _hf_errno() != 2:
            _ = external_call["close", Int32](directory_fd)
            raise Error("Hugging Face cannot inspect download destination")

        var stage_name = target_name + (
            ".part." + expected_sha256
            if connections == 1 else ".part.XXXXXX"
        )
        var staged = _hf_cstring(stage_name)
        var staged_path = (
            "/" + stage_name if parent_path == "/"
            else parent_path + "/" + stage_name
        )
        var fd: Int32
        if connections == 1:
            # Linux O_RDWR | O_CREAT | O_NONBLOCK | O_NOFOLLOW | O_CLOEXEC.
            fd = external_call["openat64", Int32](
                directory_fd, staged.unsafe_ptr(), Int32(657474), Int32(384)
            )
        else:
            # Resolve the temporary name beneath the already opened parent;
            # the caller's parent pathname may be renamed or replaced now.
            staged_path = (
                "/proc/self/fd/" + String(directory_fd) + "/" + stage_name
            )
            var staged_full = _hf_cstring(staged_path)
            fd = external_call["mkostemp", Int32](
                staged_full.unsafe_ptr(), Int32(524288)
            )
            if fd >= 0:
                staged_path = String(unsafe_from_utf8_ptr=staged_full.unsafe_ptr())
                stage_name = _hf_filename(staged_path)
                staged = _hf_cstring(stage_name)
        if fd < 0:
            _ = external_call["close", Int32](directory_fd)
            raise Error("Hugging Face cannot lock staging file; another pull may be active")
        var stat = InlineArray[UInt64, 18](fill=0)
        if (external_call["fstat", Int32](fd, stat.unsafe_ptr()) != 0
                or stat[3] & 61440 != 32768
                or stat[3] >> 32 != UInt64(external_call["geteuid", UInt32]())
                or stat[2] != 1):
            _ = external_call["close", Int32](fd)
            _ = external_call["close", Int32](directory_fd)
            raise Error(
                "Hugging Face staging file must be a single-link owner-held regular file"
            )
        if external_call["flock", Int32](fd, 6) != 0:
            _ = external_call["close", Int32](fd)
            _ = external_call["close", Int32](directory_fd)
            raise Error("Hugging Face cannot lock staging file; another pull may be active")
        var staged_device = stat[0]
        var staged_inode = stat[1]
        var preserve_partial = False
        try:
            if connections == 1:
                var partial_size = external_call["lseek", Int64](
                    fd, Int64(0), Int32(2)
                )
                if partial_size < 0 or partial_size > Int64(expected_size):
                    raise Error("Hugging Face partial size is outside the pinned artifact")
                if partial_size < Int64(expected_size):
                    # -q disables user curlrc, including hidden insecure/proxy/output options.
                    var args: List[String] = [
                        "curl", "-q", "--fail", "--location", "--silent", "--show-error",
                        "--proto", "=https", "--proto-redir", "=https",
                        "--connect-timeout", "30", "--max-time", "7200",
                        "--speed-limit", "1024", "--speed-time", "120",
                        "--max-filesize", String(expected_size),
                        "--continue-at", "-", "--url", url, "--output",
                    ]
                    try:
                        _ = _hf_run_with_open_fd(args^, fd)
                    except error:
                        var interrupted_size = external_call["lseek", Int64](
                            fd, Int64(0), Int32(2)
                        )
                        preserve_partial = (
                            interrupted_size > 0
                            and interrupted_size < Int64(expected_size)
                            and _hf_same_inode(
                                directory_fd, staged, staged_device, staged_inode
                            )
                        )
                        raise error
            else:
                _hf_transfer(url, staged_path, fd, expected_size, connections)
            var actual_size = external_call["lseek", Int64](fd, Int64(0), Int32(2))
            if actual_size != Int64(expected_size):
                raise Error("Hugging Face downloaded size mismatch: expected "
                            + String(expected_size) + ", received " + String(actual_size))
            var header = List[Byte]()
            header.resize(8, 0)
            if external_call["pread", Int](
                fd, header.unsafe_ptr(), Int(8), Int64(0)
            ) != 8:
                raise Error("Hugging Face GGUF header read failed")
            if (header[0] != 71 or header[1] != 71 or header[2] != 85
                    or header[3] != 70 or header[4] != 3 or header[5] != 0
                    or header[6] != 0 or header[7] != 0):
                raise Error("Hugging Face download is not GGUF v3")
            var digest_args: List[String] = ["sha256sum", "--zero", "--"]
            var digest = _hf_run_with_open_fd(digest_args^, fd)
            if len(digest.bytes()) < 64 or String(digest[byte=0:64]) != expected_sha256:
                raise Error("Hugging Face downloaded SHA-256 mismatch")
            if external_call["fsync", Int32](fd) != 0:
                raise Error("Hugging Face staging synchronization failed")
            # Publish the exact verified descriptor, not a replaceable stage path.
            var proc_path = _hf_cstring("/proc/self/fd/" + String(fd))
            if external_call["linkat", Int32](
                Int32(-100), proc_path.unsafe_ptr(), directory_fd,
                target.unsafe_ptr(), Int32(1024)
            ) != 0:
                raise Error("Hugging Face cannot publish download; destination may exist")
            var published_stat = InlineArray[UInt64, 18](fill=0)
            if (external_call["fstatat", Int32](
                    directory_fd, target.unsafe_ptr(), published_stat.unsafe_ptr(),
                    Int32(256)
                ) != 0 or published_stat[0] != staged_device
                    or published_stat[1] != staged_inode):
                raise Error("Hugging Face published inode identity mismatch")
            if external_call["fsync", Int32](directory_fd) != 0:
                raise Error("Hugging Face output directory synchronization failed")
        except error:
            _ = external_call["close", Int32](fd)
            if not preserve_partial:
                _ = _hf_unlink_stage_if_same(
                    directory_fd, staged, staged_device, staged_inode
                )
            _ = external_call["close", Int32](directory_fd)
            raise error
        _ = external_call["close", Int32](fd)
        var cleanup = _hf_unlink_stage_if_same(
            directory_fd, staged, staged_device, staged_inode
        )
        _ = external_call["close", Int32](directory_fd)
        if cleanup < 0:
            raise Error("Hugging Face file published but staging cleanup failed")
        if cleanup == 0:
            print("[HF] staging pathname changed; foreign entry preserved")
        print("[HF] verified bytes=" + String(expected_size)
              + " sha256=" + expected_sha256 + " revision=" + revision)
        return True
