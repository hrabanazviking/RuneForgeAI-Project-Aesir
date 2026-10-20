# Original regular shard descriptor ownership; no parser/model/device execution.
from hailbru.syscall import (
    os_host_architecture, os_open_model_directory, os_open_beneath,
    os_fd_regular_size, os_close, errno_now,
)


@fieldwise_init
struct SourceRootPolicy(Copyable, Movable):
    var path_bytes: Int
    var files: Int
    var work: Int
    var source_bytes: Int


struct SourceRegularFile(Movable):
    var arch: String
    var fd: Int64
    var label: String
    var source_path: String
    var source_bytes: Int64

    def __init__(out self):
        self.arch = String("")
        self.fd = -1
        self.label = String("")
        self.source_path = String("")
        self.source_bytes = 0

    def __deinit__(deinit self):
        if self.fd >= 0:
            if os_close(self.arch, self.fd) != 0:
                print("SourceRoot: implicit regular-file close failed")

    def close(mut self) raises:
        if self.fd < 0:
            return
        var fd = self.fd
        self.fd = -1
        if os_close(self.arch, fd) != 0:
            raise Error("SourceRoot: regular-file close failed: " + String(errno_now()))

    def take_fd(mut self) raises -> Int64:
        if self.fd < 0:
            raise Error("SourceRoot: regular-file ownership already released")
        var fd = self.fd
        self.fd = -1
        return fd


struct SourceModelRoot(Movable):
    var arch: String
    var source_path: String
    var fd: Int64
    var policy: SourceRootPolicy
    var attempts: Int
    var work_units: Int

    def __init__(out self):
        self.arch = String("")
        self.source_path = String("")
        self.fd = -1
        self.policy = SourceRootPolicy(0, 0, 0, 0)
        self.attempts = 0
        self.work_units = 0

    def __deinit__(deinit self):
        if self.fd >= 0:
            if os_close(self.arch, self.fd) != 0:
                print("SourceRoot: implicit directory close failed")

    def close(mut self) raises:
        if self.fd < 0:
            return
        var fd = self.fd
        self.fd = -1
        if os_close(self.arch, fd) != 0:
            raise Error("SourceRoot: directory close failed: " + String(errno_now()))

    def open_file(mut self, label: String) raises -> SourceRegularFile:
        if self.fd < 0:
            raise Error("SourceRoot: live model directory required")
        if self.policy.path_bytes <= 0 or self.policy.path_bytes > 4095 or self.policy.files <= 0 or self.policy.work <= 0 or self.policy.source_bytes <= 0:
            raise Error("SourceRoot: mutated invalid policy")
        if self.attempts < 0 or self.attempts > self.policy.files or self.work_units < 0 or self.work_units > self.policy.work:
            raise Error("SourceRoot: invalid admission accounting state")
        var n = label.byte_length()
        if n == 0 or n > self.policy.path_bytes or "\0" in label:
            raise Error("SourceRoot: label byte policy or NUL refusal")
        if label.as_bytes()[0] == 47:
            raise Error("SourceRoot: absolute label refused")
        var cost = n + 1
        if self.attempts >= self.policy.files or cost > self.policy.work - self.work_units:
            raise Error("SourceRoot: file-attempt/work policy exceeded")
        self.attempts += 1
        self.work_units += cost
        var result = SourceRegularFile()
        result.arch = self.arch
        result.label = label
        result.source_path = self.source_path + "/" + label
        result.fd = os_open_beneath(self.arch, self.fd, label)
        if result.fd < 0:
            raise Error("SourceRoot: beneath-root open failed: " + String(errno_now()))
        try:
            result.source_bytes = os_fd_regular_size(self.arch, result.fd)
            if result.source_bytes > Int64(self.policy.source_bytes):
                raise Error("SourceRoot: regular-file extent exceeds source byte policy")
        except e:
            result.close()
            raise e
        return result^


def open_source_model_root(path: String, policy: SourceRootPolicy) raises -> SourceModelRoot:
    if policy.path_bytes <= 0 or policy.path_bytes > 4095 or policy.files <= 0 or policy.work <= 0 or policy.source_bytes <= 0:
        raise Error("SourceRoot: positive policies and path bytes at most4095 required")
    var n = path.byte_length()
    if n == 0 or n > policy.path_bytes or "\0" in path or n > policy.work:
        raise Error("SourceRoot: root path byte/work policy or NUL refusal")
    var result = SourceModelRoot()
    result.arch = os_host_architecture()
    result.source_path = path
    result.policy = policy.copy()
    result.work_units = n
    result.fd = os_open_model_directory(result.arch, path)
    if result.fd < 0:
        raise Error("SourceRoot: directory open failed: " + String(errno_now()))
    return result^
