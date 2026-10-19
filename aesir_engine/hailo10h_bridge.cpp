#include <hailo/genai/llm/llm.hpp>
#include <hailo/device.hpp>
#include <hailo/vdevice.hpp>
#include <openssl/evp.h>

#include <algorithm>
#include <array>
#include <cerrno>
#include <cstdint>
#include <cstdlib>
#include <cstring>
#include <limits>
#include <memory>
#include <mutex>
#include <string>
#include <stdexcept>
#include <unordered_map>
#include <vector>
#include <fcntl.h>
#include <sys/stat.h>
#include <unistd.h>

namespace {
struct ReadOnlyFile {
    int fd;
    // A FIFO can block in open before fstat gets the chance to reject it.
    // O_NONBLOCK has no effect on regular-file reads; other types fail below.
    explicit ReadOnlyFile(const char *path) : fd(::open(path, O_RDONLY | O_CLOEXEC | O_NONBLOCK)) {
        if (fd < 0) throw std::runtime_error(std::string("ModelArtifactOpen: ") + std::strerror(errno));
    }
    ReadOnlyFile(const ReadOnlyFile &) = delete;
    ReadOnlyFile &operator=(const ReadOnlyFile &) = delete;
    ~ReadOnlyFile() { if (fd >= 0) ::close(fd); }
};

struct ModelArtifact {
    ReadOnlyFile file;
    struct stat identity{};
    std::string digest;
    std::string load_path;

    explicit ModelArtifact(const char *path) : file(path) {
        if (::fstat(file.fd, &identity) != 0 || !S_ISREG(identity.st_mode) || identity.st_size <= 0)
            throw std::runtime_error("ModelArtifactRequired: expected a nonempty regular file");
        std::unique_ptr<EVP_MD_CTX, decltype(&EVP_MD_CTX_free)> context(EVP_MD_CTX_new(), EVP_MD_CTX_free);
        if (!context || EVP_DigestInit_ex(context.get(), EVP_sha256(), nullptr) != 1)
            throw std::runtime_error("ModelArtifactHash: cannot initialize SHA-256");
        std::array<unsigned char, 65536> chunk{};
        while (true) {
            const auto count = ::read(file.fd, chunk.data(), chunk.size());
            if (count < 0 && errno == EINTR) continue;
            if (count < 0) throw std::runtime_error("ModelArtifactHash: read failed");
            if (count == 0) break;
            if (EVP_DigestUpdate(context.get(), chunk.data(), static_cast<size_t>(count)) != 1)
                throw std::runtime_error("ModelArtifactHash: SHA-256 update failed");
        }
        std::array<unsigned char, EVP_MAX_MD_SIZE> raw{};
        unsigned int length = 0;
        if (EVP_DigestFinal_ex(context.get(), raw.data(), &length) != 1 || length != 32)
            throw std::runtime_error("ModelArtifactHash: SHA-256 finalization failed");
        constexpr char hex[] = "0123456789abcdef";
        for (unsigned int i = 0; i < length; ++i) {
            digest += hex[raw[i] >> 4]; digest += hex[raw[i] & 15];
        }
        if (::lseek(file.fd, 0, SEEK_SET) < 0)
            throw std::runtime_error("ModelArtifactHash: cannot rewind file");
        // Linux procfs binds SDK loading to the inode actually fingerprinted.
        // Keep this descriptor alive throughout the owning model session.
        // HailoRT may check the path from a helper process: address the
        // owning process explicitly instead of resolving that helper's self.
        load_path = "/proc/" + std::to_string(::getpid()) + "/fd/" + std::to_string(file.fd);
        check_unchanged();
    }

    void check_unchanged() const {
        struct stat after{};
        if (::fstat(file.fd, &after) != 0 || identity.st_dev != after.st_dev
            || identity.st_ino != after.st_ino || identity.st_size != after.st_size
            || identity.st_mtim.tv_sec != after.st_mtim.tv_sec || identity.st_mtim.tv_nsec != after.st_mtim.tv_nsec
            || identity.st_ctim.tv_sec != after.st_ctim.tv_sec || identity.st_ctim.tv_nsec != after.st_ctim.tv_nsec)
            throw std::runtime_error("ModelArtifactChanged: file changed during hashing/loading; retry with stable model bytes");
    }
};

struct Session {
    std::shared_ptr<hailort::VDevice> device;
    std::shared_ptr<ModelArtifact> artifact;
    std::unique_ptr<hailort::genai::LLM> llm;
    std::mutex mutex;
    std::string identity_json;
    bool needs_reset = false;
    bool needs_reopen = false;
    std::string last_completion = "none";
};

// A public handle is an opaque monotonically assigned ID, never a raw pointer.
// Each call holds a shared owner so concurrent close cannot free its session.
std::mutex sessions_mutex;
std::unordered_map<uint64_t, std::shared_ptr<Session>> sessions;
uint64_t next_handle = 1;
// Admission policy for the structured single-user-message template. This is
// reserved headroom, not a claimed measured tokenizer/property of the chip.
constexpr size_t TEMPLATE_TOKEN_RESERVE = 64;

std::shared_ptr<Session> lookup(uint64_t handle) {
    std::lock_guard<std::mutex> lock(sessions_mutex);
    auto found = sessions.find(handle);
    return found == sessions.end() ? nullptr : found->second;
}

hailo_status restore_context(Session &session, const hailort::BufferPtr &previous) {
    const auto status = previous
        ? session.llm->load_context(hailort::MemoryView(previous))
        : session.llm->clear_context();
    session.needs_reset = status != HAILO_SUCCESS;
    return status;
}

void copy_error(char *out, size_t cap, const std::string &message) {
    if (!out || cap == 0) return;
    const size_t n = std::min(cap - 1, message.size());
    std::memcpy(out, message.data(), n);
    out[n] = '\0';
}

std::string status_error(const char *where, hailo_status status) {
    const char *name = hailo_get_status_message(status);
    return std::string(where) + " failed: " + (name ? name : "unknown HailoRT error")
        + " (" + std::to_string(static_cast<int>(status)) + ")";
}

std::string json_quote(const char *value) {
    std::string out = "\"";
    for (const unsigned char *p = reinterpret_cast<const unsigned char *>(value); *p; ++p) {
        switch (*p) {
        case '"': out += "\\\""; break;
        case '\\': out += "\\\\"; break;
        case '\b': out += "\\b"; break;
        case '\f': out += "\\f"; break;
        case '\n': out += "\\n"; break;
        case '\r': out += "\\r"; break;
        case '\t': out += "\\t"; break;
        default:
            if (*p < 0x20) {
                static const char hex[] = "0123456789abcdef";
                out += "\\u00";
                out += hex[*p >> 4];
                out += hex[*p & 0xf];
            } else {
                out += static_cast<char>(*p);
            }
        }
    }
    out += '"';
    return out;
}
} // namespace

extern "C" int aesir_hailo10h_open(const char *hef_path, uint64_t *handle_out,
                                      char *error_out, size_t error_cap) {
    if (handle_out) *handle_out = 0;
    if (!hef_path || !handle_out) {
        copy_error(error_out, error_cap, "model path and handle output are required");
        return -1;
    }
    try {
        if (std::strlen(hef_path) == 0 || std::strlen(hef_path) >= 4096) {
            copy_error(error_out, error_cap, "model path must contain 1..4095 bytes"); return -1;
        }
        auto artifact = std::make_shared<ModelArtifact>(hef_path);
        auto device = hailort::VDevice::create_shared();
        if (!device) {
            copy_error(error_out, error_cap, status_error("VDevice::create_shared", device.status()));
            return static_cast<int>(device.status());
        }
        // Admit the actual physical device, rather than relying on a model
        // filename or library presence as proof of the inference target.
        auto physical = device->get()->get_physical_devices();
        if (!physical || physical->size() != 1) {
            copy_error(error_out, error_cap, "HailoDeviceRequired: exactly one physical Hailo-10H is required");
            return -1;
        }
        auto &chip = physical->front().get();
        auto identity = chip.identify();
        if (!identity) {
            copy_error(error_out, error_cap, status_error("Device::identify", identity.status()));
            return static_cast<int>(identity.status());
        }
        if (identity->device_architecture != HAILO_ARCH_HAILO10H) {
            copy_error(error_out, error_cap, "HailoOnlyBackendRequired: selected device is not Hailo-10H");
            return -1;
        }
        hailo_version_t version{};
        auto version_status = hailo_get_library_version(&version);
        if (version_status != HAILO_SUCCESS) {
            copy_error(error_out, error_cap, status_error("hailo_get_library_version", version_status));
            return static_cast<int>(version_status);
        }
        hailort::genai::LLMParams params(artifact->load_path);
        auto created = hailort::genai::LLM::create(device.value(), params);
        if (!created) {
            copy_error(error_out, error_cap, status_error("LLM::create", created.status()));
            return static_cast<int>(created.status());
        }
        artifact->check_unchanged();
        auto identity_json = std::string("{\"backend\":\"hailort-genai\",\"architecture\":\"HAILO10H\",\"device_id\":")
            + json_quote(chip.get_dev_id()) + ",\"model_path\":" + json_quote(hef_path)
            + ",\"model_sha256\":" + json_quote(artifact->digest.c_str())
            + ",\"model_size_bytes\":" + std::to_string(artifact->identity.st_size)
            + ",\"runtime_version\":\"" + std::to_string(version.major) + "."
            + std::to_string(version.minor) + "." + std::to_string(version.revision)
            + "\",\"firmware_version\":\"" + std::to_string(identity->fw_version.major) + "."
            + std::to_string(identity->fw_version.minor) + "." + std::to_string(identity->fw_version.revision)
            + "\"";
        auto session = std::shared_ptr<Session>(new Session{
            device.value(), artifact, std::make_unique<hailort::genai::LLM>(std::move(created.value())), {}, identity_json
        });
        std::lock_guard<std::mutex> lock(sessions_mutex);
        if (next_handle == 0) {
            copy_error(error_out, error_cap, "session ID space exhausted"); return -1;
        }
        const auto handle = next_handle++;
        sessions.emplace(handle, std::move(session));
        *handle_out = handle;
        copy_error(error_out, error_cap, "");
        return 0;
    } catch (const std::exception &e) {
        copy_error(error_out, error_cap, e.what());
        return -1;
    } catch (...) {
        copy_error(error_out, error_cap, "unknown native exception in open"); return -1;
    }
}

extern "C" int aesir_hailo10h_describe(uint64_t handle, char *output, size_t output_cap,
                                        char *error_out, size_t error_cap) {
    if (!handle || !output || output_cap == 0) {
        copy_error(error_out, error_cap, "invalid session description arguments"); return -1;
    }
    try {
        auto session = lookup(handle);
        if (!session) { copy_error(error_out, error_cap, "session is closed or invalid"); return -1; }
        std::lock_guard<std::mutex> lock(session->mutex);
        auto capacity = session->llm->max_context_capacity();
        auto usage = session->llm->get_context_usage_size();
        if (!capacity || !usage) {
            copy_error(error_out, error_cap, "cannot query Hailo model context capacity/usage"); return -1;
        }
        auto json = session->identity_json + ",\"context_capacity\":" + std::to_string(capacity.value())
            + ",\"context_usage\":" + std::to_string(usage.value())
            + ",\"needs_reset\":" + (session->needs_reset ? "true" : "false")
            + ",\"needs_reopen\":" + (session->needs_reopen ? "true" : "false")
            + ",\"last_completion\":" + json_quote(session->last_completion.c_str());
        json += ",\"template_token_reserve\":" + std::to_string(TEMPLATE_TOKEN_RESERVE);
        auto stop_tokens = session->llm->get_stop_tokens();
        if (!stop_tokens) {
            copy_error(error_out, error_cap, status_error("get_stop_tokens", stop_tokens.status()));
            return static_cast<int>(stop_tokens.status());
        }
        json += ",\"stop_tokens\":[";
        for (size_t i = 0; i < stop_tokens->size(); ++i) {
            if (i) json += ",";
            json += json_quote((*stop_tokens)[i].c_str());
        }
        json += "]}";
        if (json.size() >= output_cap) {
            copy_error(error_out, error_cap, "session description exceeds caller buffer"); return -2;
        }
        std::memcpy(output, json.c_str(), json.size() + 1);
        return 0;
    } catch (const std::exception &e) {
        copy_error(error_out, error_cap, e.what()); return -1;
    } catch (...) {
        copy_error(error_out, error_cap, "unknown native exception in describe"); return -1;
    }
}

extern "C" int aesir_hailo10h_generate(uint64_t handle, const char *prompt,
                                          uint32_t max_tokens, uint32_t timeout_ms,
                                          char **output, size_t *output_len,
                                          char *error_out, size_t error_cap) {
    if (output) *output = nullptr;
    if (output_len) *output_len = 0;
    if (!handle || !prompt || !output || !output_len || max_tokens == 0 || timeout_ms == 0) {
        copy_error(error_out, error_cap, "invalid generation arguments");
        return -1;
    }
    try {
        auto session = lookup(handle);
        if (!session) { copy_error(error_out, error_cap, "session is closed or invalid"); return -1; }
        std::lock_guard<std::mutex> lock(session->mutex);
        if (session->needs_reopen) {
            copy_error(error_out, error_cap, "SessionRequiresReopen: restart this Hailo chat session"); return -1;
        }
        if (session->needs_reset) {
            copy_error(error_out, error_cap, "SessionNeedsReset: use /clear before another request"); return -1;
        }
        auto capacity = session->llm->max_context_capacity();
        if (!capacity) {
            copy_error(error_out, error_cap, status_error("max_context_capacity", capacity.status()));
            return static_cast<int>(capacity.status());
        }
        if (max_tokens > capacity.value()) {
            copy_error(error_out, error_cap, "requested output tokens exceed the Hailo model context capacity"); return -1;
        }
        auto params = session->llm->create_generator_params();
        if (!params) {
            copy_error(error_out, error_cap, status_error("create_generator_params", params.status()));
            return static_cast<int>(params.status());
        }
        if (auto s = params->set_max_generated_tokens(max_tokens); HAILO_SUCCESS != s) {
            copy_error(error_out, error_cap, status_error("set_max_generated_tokens", s)); return static_cast<int>(s);
        }
        if (auto s = params->set_do_sample(false); HAILO_SUCCESS != s) {
            copy_error(error_out, error_cap, status_error("set_do_sample", s)); return static_cast<int>(s);
        }
        // Preserve completed turns before submitting input which can mutate
        // device context. The snapshot is opaque state, never host inference.
        auto usage = session->llm->get_context_usage_size();
        if (!usage) {
            copy_error(error_out, error_cap, status_error("get_context_usage_size", usage.status()));
            return static_cast<int>(usage.status());
        }
        auto prompt_tokens = session->llm->tokenize(prompt);
        if (!prompt_tokens) {
            copy_error(error_out, error_cap, status_error("Hailo prompt tokenize", prompt_tokens.status()));
            return static_cast<int>(prompt_tokens.status());
        }
        if (usage.value() > capacity.value()
            || max_tokens > capacity.value() - usage.value()
            || prompt_tokens->size() > capacity.value() - usage.value() - max_tokens
            || TEMPLATE_TOKEN_RESERVE > capacity.value() - usage.value() - max_tokens - prompt_tokens->size()) {
            copy_error(error_out, error_cap,
                "ContextCapacityExceeded: prompt, output budget and template reserve do not fit; "
                "shorten the request or max-tokens, or use /clear to start a new conversation");
            return -1;
        }
        hailort::BufferPtr previous_context;
        if (usage.value() != 0) {
            auto saved = session->llm->save_context();
            if (!saved) {
                copy_error(error_out, error_cap, status_error("save_context", saved.status()));
                return static_cast<int>(saved.status());
            }
            previous_context = saved.value();
        }
        std::vector<std::string> messages{
            std::string("{\"role\":\"user\",\"content\":") + json_quote(prompt) + "}"
        };
        auto completion = session->llm->generate(params.value(), messages);
        if (!completion) {
            const auto restored = restore_context(*session, previous_context);
            session->last_completion = "request_failed";
            auto message = status_error("LLM::generate", completion.status())
                + (restored != HAILO_SUCCESS ? "; context restoration failed, use /clear or reopen"
                    : previous_context ? "; previous context restored, adjust the request and retry"
                    : "; empty context restored, adjust the request and retry");
            copy_error(error_out, error_cap, message);
            return static_cast<int>(completion.status());
        }
        auto text = completion->read_all(std::chrono::milliseconds(timeout_ms));
        if (!text) {
            // Stop the original request before permitting any retry. There is
            // no automatic replay: clearing discards partially updated context.
            const auto abort_status = completion->abort();
            const auto clear_status = abort_status == HAILO_SUCCESS
                ? restore_context(*session, previous_context) : abort_status;
            session->needs_reopen = abort_status != HAILO_SUCCESS;
            session->needs_reset = clear_status != HAILO_SUCCESS;
            session->last_completion = "read_failed";
            auto message = status_error("completion.read_all", text.status());
            if (abort_status != HAILO_SUCCESS) message += "; " + status_error("abort", abort_status);
            else if (clear_status != HAILO_SUCCESS) message += "; " + status_error("recovery restore_context", clear_status);
            else message += previous_context
                ? "; generation aborted and previous context restored; retry the request"
                : "; generation aborted and context cleared; retry the request";
            if (session->needs_reopen) message += "; restart this Hailo session before retrying";
            copy_error(error_out, error_cap, message);
            return static_cast<int>(text.status());
        }
        switch (completion->generation_status()) {
        case hailort::genai::LLMGeneratorCompletion::Status::MAX_TOKENS_REACHED:
            session->last_completion = "max_tokens"; break;
        case hailort::genai::LLMGeneratorCompletion::Status::LOGICAL_END_OF_GENERATION:
            session->last_completion = "end_of_generation"; break;
        case hailort::genai::LLMGeneratorCompletion::Status::ABORTED:
            session->last_completion = "aborted"; break;
        default:
            copy_error(error_out, error_cap, "Hailo generation did not reach a terminal status"); return -1;
        }
        // Hide only a complete terminal suffix actually configured by the
        // loaded model. Never remove an internal or hardcoded model token.
        if (session->last_completion == "end_of_generation") {
            auto stops = session->llm->get_stop_tokens();
            size_t remove = 0;
            if (stops) {
                for (const auto &stop : stops.value()) {
                    if (!stop.empty() && stop.size() <= text->size()
                        && text->compare(text->size() - stop.size(), stop.size(), stop) == 0) {
                        remove = std::max(remove, stop.size());
                    }
                }
            }
            if (remove) text->resize(text->size() - remove);
        }
        if (text->size() == std::numeric_limits<size_t>::max()) {
            copy_error(error_out, error_cap, "generated output size overflow"); return -1;
        }
        auto allocated = static_cast<char *>(std::malloc(text->size() + 1));
        if (!allocated) { copy_error(error_out, error_cap, "cannot allocate generated text buffer"); return -1; }
        std::memcpy(allocated, text->c_str(), text->size() + 1);
        *output_len = text->size();
        *output = allocated;
        copy_error(error_out, error_cap, "");
        return 0;
    } catch (const std::exception &e) {
        copy_error(error_out, error_cap, e.what());
        return -1;
    } catch (...) {
        copy_error(error_out, error_cap, "unknown native exception in generate"); return -1;
    }
}

extern "C" int aesir_hailo10h_clear_context(uint64_t handle, char *error_out, size_t error_cap) {
    if (!handle) { copy_error(error_out, error_cap, "invalid session handle"); return -1; }
    try {
        auto session = lookup(handle);
        if (!session) { copy_error(error_out, error_cap, "session is closed or invalid"); return -1; }
        std::lock_guard<std::mutex> lock(session->mutex);
        if (session->needs_reopen) {
            copy_error(error_out, error_cap, "SessionRequiresReopen: abort did not confirm stopped generation; restart this Hailo session");
            return -1;
        }
        const auto status = session->llm->clear_context();
        if (HAILO_SUCCESS != status) { copy_error(error_out, error_cap, status_error("clear_context", status)); return static_cast<int>(status); }
        session->needs_reset = false;
        session->last_completion = "context_cleared";
        copy_error(error_out, error_cap, ""); return 0;
    } catch (const std::exception &e) {
        copy_error(error_out, error_cap, e.what()); return -1;
    } catch (...) {
        copy_error(error_out, error_cap, "unknown native exception in clear_context"); return -1;
    }
}

extern "C" void aesir_hailo10h_free_text(char *text) noexcept {
    std::free(text);
}

extern "C" int aesir_hailo10h_close(uint64_t handle) noexcept {
    try {
        std::shared_ptr<Session> release;
        {
            std::lock_guard<std::mutex> lock(sessions_mutex);
            auto found = sessions.find(handle);
            if (found != sessions.end()) {
                release = std::move(found->second);
                sessions.erase(found);
            }
        }
        // Destruction occurs outside the registry lock and after in-flight
        // calls drop their owner. Closing an already closed ID is harmless.
        return 0;
    } catch (...) { return -1; }
}
