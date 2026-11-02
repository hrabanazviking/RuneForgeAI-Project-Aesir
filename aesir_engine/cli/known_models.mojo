"""The curated known-models catalogue dataset (J-103).

This module is data, not logic: it constructs exactly the catalogue
entries behind cli.model_selector.known_model_catalogue(). Every
entry's pins come from a real, citable source (J-103 doc section 0.3):
the sha256 and size were measured first-hand by the road's own filed
records and matched against the publisher's Hugging Face LFS oid, and
the revision is the repo's HEAD commit reported by the Hugging Face
API, cross-checked in the same pass (2026-11-01) against the repo
tree at that revision -- the file's LFS oid and size there equal the
filed pin and size below. An entry that cannot clear both bars is
not included; no pin, revision, or size is ever invented here.

Catalogue data is kept in the repo as data; models are never
committed. The download/verify engine is pull's (download_hf_model +
DurableModelStore.ingest_model), reached through J-102's
fetch_known_model -- nothing here downloads or hashes.
"""
from cli.model_selector import KnownModelEntry


def known_models_dataset() -> List[KnownModelEntry]:
    """The curated catalogue: five entries, each fully pin-verified.

    Provenance per entry is stated in the comment above it (source
    record + what it pins + the live cross-check). Keep this list
    small and fully verified: a handful of entries with perfect
    provenance beats a long list with gaps (J-103 doc section 0.3).
    """
    var entries = List[KnownModelEntry]()

    # olmoe-1b-7b:q4_k_m -- the publisher's own GGUF repo (AllenAI).
    # Source: J-015 section 1 (J015_MOE_ANATOMY.md): file downloaded
    # and hashed first-hand; sha256 + size match the HF LFS oid.
    # Revision: HF API HEAD for the repo, tree cross-checked
    # 2026-11-01 (LFS oid == filed sha256, LFS size == filed size).
    entries.append(KnownModelEntry(
        "olmoe-1b-7b", "q4_k_m",
        "allenai/OLMoE-1B-7B-0924-Instruct-GGUF",
        "olmoe-1b-7b-0924-instruct-q4_k_m.gguf",
        "02ab6ea6894a8418eb14f6d8ee1bfb08bd298080",
        "8c310f1435a1222338fd2d3d974975be9cd908180b644bab0c2a94da1ac32f3f",
        4213512672, "Q4_K_M",
    ))

    # granite-3.1-3b-a800m:q4_k_m -- IBM Granite MoE, bartowski build.
    # Source: J-015 section 1: file downloaded and hashed first-hand;
    # sha256 + size match the HF LFS oid. Revision: HF API HEAD,
    # tree cross-checked 2026-11-01 (oid + size equal the filed pin).
    entries.append(KnownModelEntry(
        "granite-3.1-3b-a800m", "q4_k_m",
        "bartowski/granite-3.1-3b-a800m-instruct-GGUF",
        "granite-3.1-3b-a800m-instruct-Q4_K_M.gguf",
        "be9a36f042806cb586bc65556c527079782b78e0",
        "48e0edcd578fd4462f26127f04c651d0e650741110185297741089aea01a82b3",
        2016888384, "Q4_K_M",
    ))

    # qwen1.5-moe-a2.7b-chat:q2_k -- Qwen1.5-MoE, tensorblock mirror
    # (Qwen's own GGUF repo answered HTTP 401 in J-015's pass).
    # Source: J-015 section 7 (witness C): bytes + sha256 stated
    # there to match the repo's HF LFS oid exactly. Revision: HF API
    # HEAD, tree cross-checked 2026-11-01 (oid + size equal).
    entries.append(KnownModelEntry(
        "qwen1.5-moe-a2.7b-chat", "q2_k",
        "tensorblock/Qwen1.5-MoE-A2.7B-Chat-GGUF",
        "Qwen1.5-MoE-A2.7B-Chat-Q2_K.gguf",
        "2b36b746552a7c99c814ee43120f318391e608c5",
        "cce008140714bb8b76185c0e2db802c60ce62182fa2eddb86ac53303b7525986",
        5890164032, "Q2_K",
    ))

    # olmoe-1b-7b:q2_k -- the same model family's smallest Q2_K file,
    # bartowski build (parser-validation fodder in J-015).
    # Source: J-015 section 7 (fourth file): bytes + sha256 stated
    # there to match its HF LFS oid. Revision: HF API HEAD, tree
    # cross-checked 2026-11-01 (oid + size equal the filed pin).
    entries.append(KnownModelEntry(
        "olmoe-1b-7b", "q2_k",
        "bartowski/OLMoE-1B-7B-0924-Instruct-GGUF",
        "OLMoE-1B-7B-0924-Instruct-Q2_K.gguf",
        "7448e4317d367a3d6838fe367fe996758da6fc6e",
        "0b6554d40b4ae1ed84c20f0411b7869c10da264e826b8f185758cfd02e782b33",
        2562763584, "Q2_K",
    ))

    # qwen3-next-80b-a3b:q4_k_m -- the 80B-class target (J-022/J-032).
    # Source: J-022 section 5, re-verified in J-032 section 3: size +
    # full sha256 re-read and matched character-for-character, stated
    # to match the HuggingFace LFS pin exactly. Revision: HF API
    # HEAD, tree cross-checked 2026-11-01 (oid + size equal).
    entries.append(KnownModelEntry(
        "qwen3-next-80b-a3b", "q4_k_m",
        "unsloth/Qwen3-Next-80B-A3B-Instruct-GGUF",
        "Qwen3-Next-80B-A3B-Instruct-Q4_K_M.gguf",
        "6688872b7a4e5eb8a121ceea08009530a024ba1d",
        "f73551b55e3796526c37772c96227151fa11af328802b8f9865d635104e280fd",
        48506100512, "Q4_K_M",
    ))

    return entries^
