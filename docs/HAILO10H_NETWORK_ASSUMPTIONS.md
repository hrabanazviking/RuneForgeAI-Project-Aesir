# Hailo-10H network assumptions

**Roadmap Slice 007 — complete: offline and network behavior**

## Runtime assumption

Once the supported Hailo runtime and a compatible model artifact are installed,
the primary text-generation interaction must run locally without sending
prompts, conversation text, or model inference to a cloud service. Network loss
after installation must not cause a switch to a remote or Pi CPU LLM backend.

## Setup-time network use

Internet access may be needed to obtain OS packages, Hailo software, model
artifacts, or updates. These are setup/update operations, not inference. The
software must report which artifacts are missing and must not download an
unverified substitute during a user request.

## Local service exposure

The first service deployment is local to the Pi. Bind to loopback by default;
LAN exposure, authentication, and remote clients require a later explicit
security design. If Æsir communicates with a separate Hailo service, the
endpoint and process ownership must be configured and visible in diagnostics.

## Slice 007 acceptance

- Runtime inference is defined as local and independent of cloud inference.
- Setup/model-download network requirements are separated from runtime.
- Loss of network cannot change the selected inference backend.
- Local service binding is loopback by default until reviewed otherwise.
