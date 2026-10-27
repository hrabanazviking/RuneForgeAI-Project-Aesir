/* hailo10h_stub.c — Fail-closed stub for the Hailo-10H C ABI.
 *
 * The canonical Aesir binary references the aesir_hailo10h_* C ABI
 * (see HAILO10H_INTERFACE.md) implemented for Hailo machines by
 * hailo10h_bridge.cpp, which requires the HailoRT runtime. On machines
 * without HailoRT (for example CPU-only x86-64 hosts) the real bridge
 * cannot be built, so scripts/launch.py compiles THIS stub into
 * libaesir_hailo10h.so and links the launcher build against it.
 *
 * Every entry point fails closed: session creation reports that the
 * Hailo-10H backend is unavailable on this platform, no session is
 * ever created, and no inference is performed. Build the real bridge
 * with scripts/build_hailo10h.sh on a host with HailoRT installed.
 */

#include <stddef.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>

static const char kUnavailableMessage[] =
    "Hailo-10H backend is unavailable on this platform: this Aesir "
    "binary was linked with the fail-closed stub bridge "
    "(aesir_engine/hailo10h_stub.c) because HailoRT is not installed. "
    "Build the real bridge with scripts/build_hailo10h.sh on a host "
    "with HailoRT, or use a CPU/CUDA execution route.";

static void copy_error(char *error_out, size_t error_cap) {
    if (!error_out || error_cap == 0) {
        return;
    }
    size_t length = strlen(kUnavailableMessage);
    if (length >= error_cap) {
        length = error_cap - 1;
    }
    memcpy(error_out, kUnavailableMessage, length);
    error_out[length] = '\0';
}

int aesir_hailo10h_open(const char *hef_path, uint64_t *handle_out,
                        char *error_out, size_t error_cap) {
    (void)hef_path;
    if (handle_out) {
        *handle_out = 0;
    }
    copy_error(error_out, error_cap);
    return -1;
}

int aesir_hailo10h_describe(uint64_t handle, char *output, size_t output_cap,
                            char *error_out, size_t error_cap) {
    (void)handle;
    (void)output;
    (void)output_cap;
    copy_error(error_out, error_cap);
    return -1;
}

int aesir_hailo10h_generate(uint64_t handle, const char *prompt,
                            uint32_t max_tokens, uint32_t timeout_ms,
                            char **output, size_t *output_len,
                            char *error_out, size_t error_cap) {
    (void)handle;
    (void)prompt;
    (void)max_tokens;
    (void)timeout_ms;
    if (output) {
        *output = NULL;
    }
    if (output_len) {
        *output_len = 0;
    }
    copy_error(error_out, error_cap);
    return -1;
}

int aesir_hailo10h_clear_context(uint64_t handle, char *error_out,
                                 size_t error_cap) {
    (void)handle;
    copy_error(error_out, error_cap);
    return -1;
}

void aesir_hailo10h_free_text(char *text) {
    free(text);
}

int aesir_hailo10h_close(uint64_t handle) {
    /* No session can exist through the stub, so close is a no-op. */
    (void)handle;
    return 0;
}
