#include <hailo/genai/llm/llm.hpp>
#include <hailo/vdevice.hpp>

#include <algorithm>
#include <cstdint>
#include <cstring>
#include <memory>
#include <mutex>
#include <string>
#include <vector>

namespace {
struct Session {
    std::shared_ptr<hailort::VDevice> device;
    std::unique_ptr<hailort::genai::LLM> llm;
    std::mutex mutex;
};

void copy_error(char *out, size_t cap, const std::string &message) {
    if (!out || cap == 0) return;
    const size_t n = std::min(cap - 1, message.size());
    std::memcpy(out, message.data(), n);
    out[n] = '\0';
}

std::string status_error(const char *where, hailo_status status) {
    return std::string(where) + " failed with HailoRT status " + std::to_string(static_cast<int>(status));
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
    if (!hef_path || !handle_out) {
        copy_error(error_out, error_cap, "model path and handle output are required");
        return -1;
    }
    try {
        auto device = hailort::VDevice::create_shared();
        if (!device) {
            copy_error(error_out, error_cap, status_error("VDevice::create_shared", device.status()));
            return static_cast<int>(device.status());
        }
        hailort::genai::LLMParams params(hef_path);
        auto created = hailort::genai::LLM::create(device.value(), params);
        if (!created) {
            copy_error(error_out, error_cap, status_error("LLM::create", created.status()));
            return static_cast<int>(created.status());
        }
        auto *session = new Session{device.value(), std::make_unique<hailort::genai::LLM>(std::move(created.value())), {}};
        *handle_out = static_cast<uint64_t>(reinterpret_cast<uintptr_t>(session));
        copy_error(error_out, error_cap, "");
        return 0;
    } catch (const std::exception &e) {
        copy_error(error_out, error_cap, e.what());
        return -1;
    }
}

extern "C" int aesir_hailo10h_generate(uint64_t handle, const char *prompt,
                                          uint32_t max_tokens, char *output,
                                          size_t output_cap, size_t *output_len,
                                          char *error_out, size_t error_cap) {
    if (!handle || !prompt || !output || output_cap == 0 || !output_len || max_tokens == 0) {
        copy_error(error_out, error_cap, "invalid generation arguments");
        return -1;
    }
    auto *session = reinterpret_cast<Session *>(static_cast<uintptr_t>(handle));
    std::lock_guard<std::mutex> lock(session->mutex);
    try {
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
        std::vector<std::string> messages{
            std::string("{\"role\":\"user\",\"content\":") + json_quote(prompt) + "}"
        };
        auto completion = session->llm->generate(params.value(), messages);
        if (!completion) {
            copy_error(error_out, error_cap, status_error("LLM::generate", completion.status()));
            return static_cast<int>(completion.status());
        }
        auto text = completion->read_all();
        if (!text) {
            copy_error(error_out, error_cap, status_error("completion.read_all", text.status()));
            return static_cast<int>(text.status());
        }
        *output_len = text->size();
        if (text->size() >= output_cap) {
            copy_error(error_out, error_cap, "generated output exceeds caller buffer");
            return -2;
        }
        std::memcpy(output, text->data(), text->size());
        output[text->size()] = '\0';
        copy_error(error_out, error_cap, "");
        return 0;
    } catch (const std::exception &e) {
        copy_error(error_out, error_cap, e.what());
        return -1;
    }
}

extern "C" int aesir_hailo10h_clear_context(uint64_t handle, char *error_out, size_t error_cap) {
    if (!handle) { copy_error(error_out, error_cap, "invalid session handle"); return -1; }
    auto *session = reinterpret_cast<Session *>(static_cast<uintptr_t>(handle));
    std::lock_guard<std::mutex> lock(session->mutex);
    const auto status = session->llm->clear_context();
    if (HAILO_SUCCESS != status) { copy_error(error_out, error_cap, status_error("clear_context", status)); return static_cast<int>(status); }
    copy_error(error_out, error_cap, "");
    return 0;
}

extern "C" void aesir_hailo10h_close(uint64_t handle) {
    delete reinterpret_cast<Session *>(static_cast<uintptr_t>(handle));
}
