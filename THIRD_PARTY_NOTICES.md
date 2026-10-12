# Third-Party Notices

## hailort-drivers (study only — no code taken)

The PCIe transport architecture documented in
`docs/plunder/HAILO_PCIE_TRANSPORT_GUIDE.md` was studied from the
hailo-ai/hailort-drivers repository (commit `309eb10`, "Update
third-party-packages.md for v5.4.0", cloned 2026-10-10). No code from this
repository was copied, translated, vendored, linked, or shipped; the study
produced original prose only, per the clean-room workflow (see
`CLEAN_ROOM_LOG.md`).

GNU GENERAL PUBLIC LICENSE, Version 2, June 1991
Copyright (C) 1989, 1991 Free Software Foundation, Inc.

## HailoRT historical study (2026-10-10 — no code taken)

The HEF container format documented in
`docs/plunder/HAILO_HEF_CONTAINER_GUIDE.md` was studied from the
hailo-ai/HailoRT repository (commit `f519590`, "v5.4.0", cloned
2026-10-10). No code from this repository was copied, translated, vendored,
linked, or shipped; the study produced original prose only, per the
clean-room workflow (see `CLEAN_ROOM_LOG.md`). No `.hef` file was
downloaded, opened, or parsed during that study. This historical study
statement does not describe the direct linked runtime added on 2026-10-12.

The MIT License (MIT)
Copyright (c) 2019-2026 Hailo Technologies Ltd.

## HailoRT direct linked runtime (2026-10-12)

The current Hailo-10H integration links the installed HailoRT 5.3.0 GenAI
runtime through Æsir's own narrow C ABI bridge. No HailoRT implementation
source is copied or vendored. The installed GenAI API header and package
copyright identify Hailo Technologies and MIT licensing. This is a separate
use from the historical clean-room studies above. Approval, dependency
versions, and external model-artifact provenance are recorded in
`docs/DEPENDENCIES.md` and `docs/HAILO10H_DECISION_LOG.md`.

The MIT License (MIT)

Copyright (c) 2019-2026 Hailo Technologies Ltd.
All rights reserved.

Permission is hereby granted, free of charge, to any person obtaining a copy of
this software and associated documentation files (the "Software"), to deal in
the Software without restriction, including without limitation the rights to
use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
the Software, and to permit persons to whom the Software is furnished to do so,
subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

The bridge also links the system GNU C++ standard runtime. Its installed
`libstdc++6` package copyright record identifies GPLv3 or later with the GCC
Runtime Library Exception 3.1. This source change does not vendor that runtime,
Hailo device firmware, or model weights. The compatible HEF used for the
narrow smoke remains an external local artifact; retain its own model and
compiled-artifact license record before packaging or redistributing it.
HailoRT's MIT license is not evidence of the model's license.

## OpenSSL linked digest API (2026-10-12)

The direct Hailo bridge links the installed OpenSSL 3.0.22 `libcrypto` EVP
digest API for model-file SHA-256 integrity. It performs ordinary host file
hashing, not LLM computation, and does not use an inference or network service.
No OpenSSL source is copied or vendored, and the existing installed package is
used without package changes. Slice 138 fingerprint/provenance acceptance is
being qualified separately.

The installed `libssl3` package copyright identifies the OpenSSL Project
Authors and contributors and the Apache License 2.0. Preserve applicable
copyright, license, and notice material if redistributing covered components.
See the [OpenSSL license](https://www.openssl.org/source/license.html) and
[official EVP digest API](https://docs.openssl.org/3.0/man3/EVP_DigestInit/).
Dependency scope and version are recorded in `docs/DEPENDENCIES.md`.

## ggml / llama.cpp format and architecture reference

Native Gemma 4 tokenizer, quantized weight decoding, and model operations are
implemented in Mojo with reference to ggml-org/llama.cpp commit
`62acc89c26c66076cb72e049f307fbe93b8b9750` (`src/llama-vocab.cpp`,
`src/models/gemma4.cpp`, `ggml/src/ggml-quants.c`, and model KV/RoPE policy).
No llama.cpp engine is linked or invoked by production inference.
The IQ2_XXS, IQ1_S, and TQ1_0 grids or decoding contracts were additionally
checked against ggml-org/llama.cpp commit
`3466812d1f06728effe7c0f3c0671117f461672d`.

MIT License

Copyright (c) 2023-2026 The ggml authors

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

## Unicode character properties

The generated Llama 3 pre-tokenizer category table is derived from Unicode
16.0.0 UnicodeData.txt. Its source hash is recorded in the generated module.

UNICODE LICENSE V3

COPYRIGHT AND PERMISSION NOTICE

Copyright © 1991-2026 Unicode, Inc.

NOTICE TO USER: Carefully read the following legal agreement. BY
DOWNLOADING, INSTALLING, COPYING OR OTHERWISE USING DATA FILES, AND/OR
SOFTWARE, YOU UNEQUIVOCALLY ACCEPT, AND AGREE TO BE BOUND BY, ALL OF THE
TERMS AND CONDITIONS OF THIS AGREEMENT. IF YOU DO NOT AGREE, DO NOT
DOWNLOAD, INSTALL, COPY, DISTRIBUTE OR USE THE DATA FILES OR SOFTWARE.

Permission is hereby granted, free of charge, to any person obtaining a
copy of data files and any associated documentation (the "Data Files") or
software and any associated documentation (the "Software") to deal in the
Data Files or Software without restriction, including without limitation
the rights to use, copy, modify, merge, publish, distribute, and/or sell
copies of the Data Files or Software, and to permit persons to whom the
Data Files or Software are furnished to do so, provided that either (a)
this copyright and permission notice appear with all copies of the Data
Files or Software, or (b) this copyright and permission notice appear in
associated Documentation.

THE DATA FILES AND SOFTWARE ARE PROVIDED "AS IS", WITHOUT WARRANTY OF ANY
KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT OF
THIRD PARTY RIGHTS.

IN NO EVENT SHALL THE COPYRIGHT HOLDER OR HOLDERS INCLUDED IN THIS NOTICE
BE LIABLE FOR ANY CLAIM, OR ANY SPECIAL INDIRECT OR CONSEQUENTIAL DAMAGES,
OR ANY DAMAGES WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS,
WHETHER IN AN ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION,
ARISING OUT OF OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THE DATA
FILES OR SOFTWARE.

Except as contained in this notice, the name of a copyright holder shall
not be used in advertising or otherwise to promote the sale, use or other
dealings in these Data Files or Software without prior written
authorization of the copyright holder.

## H194 finalization (MÍMISBRUNNR Campaign 10, 2026-10-10)

### Historical clean-room statement

The following statement records the 2026-10-10 campaign, whose CPU inference
release direction is withdrawn by the current owner scope. It does not assert
the dependency state of the direct Hailo-10H integration described above.

All vendor artifacts (hailort-drivers, HailoRT) were STUDIED ONLY under
the clean-room workflow: readers produced prose notes, implementers
worked from the notes, never from the vendor source. No vendor code was
copied, translated, vendored, linked, or shipped at any point. Evidence:
`CLEAN_ROOM_LOG.md` (H005/H006 transport + HEF studies), the C6 SMIÐR
assault logs (encoding face honestly UNKNOWN, never reconstructed from
vendor sources). No `.hef` file was ever downloaded, opened, or parsed;
no Dataflow Compiler or HailoRT library was ever installed on the build
or test hosts.

### Open-licensed artifacts used in TESTS ONLY (never shipped)

- **TinyLlama-1.1B-Chat-v1.0** (used by H059/H138/H183/H195+ test
  inference): original weights by TinyLlama team, Apache 2.0. The GGUF
  Q4_0 quantization used in tests (`tinyllama-1.1b-chat-v1.0.Q4_0.gguf`,
  sha256 `da3087fb…03b556`) is TheBloke's conversion (CC-BY-NC / Llama 2
  community terms via the original model card). The weights live outside
  the repo (`/home/pi/models/`, gitignored `*.gguf`) and are NOT part of
  the release package.
- **Unseen victory-gate models (H195)**: recorded per-run in
  `data/gauntlet/victory_gate_1.json` with name, URL, and SHA-256. Both
  inside the GGUF-or-safetensors envelope Aesir's loaders support.

### Historical shipped binary dependency-closure license scan (H194)

Method (recorded, reproducible on Mimir):
1. `ldd build/f1_infer` — dynamic linkage must show POSIX libc/libm/
   ld-linux only.
2. `grep -rhoE "^from [A-Za-z0-9_.]+" gauntlet/ armvegr/ | sort -u` —
   every import root must be `std` or one of the repo's own pure-Mojo
   packages (`armvegr`, `gauntlet`, `hailbru`, `vordr`, `smidr`).
3. `grep -rliE "gpl|affero" build/f1_infer` — no GPL marker strings in
   the binary.

Result (2026-10-10, on Mimir): PASS — Mojo stdlib + the Mojo 1.1.0
toolchain runtime libs (libKGENCompilerRTShared, libMSupportGlobals,
libAsyncRTRuntimeGlobals, libstdc++/libgcc_s from the toolchain env) +
POSIX libc/libm only. No GPL/LGPL/AGPL/proprietary linkage. No Python,
no HEF, no firmware blobs in the package (separately verified by
`scripts/package_f1_release.sh` artifact scan and
`prof/gauntlet/test_packaging.py`).

## Historical bundled runtime libraries (H190 packaging, 2026-10-11)

The release tarball bundles, unmodified, the Mojo 1.1.0 toolchain
runtime libraries that `f1_infer` dynamically links against
(libKGENCompilerRTShared.so, libMSupportGlobals.so,
libAsyncRTRuntimeGlobals.so, libstdc++.so.6, libgcc_s.so.1) under
`lib/`, with the binary's rpath set to `$ORIGIN/../lib`. Without them
the binary does not run on a clean machine (H190 container proof).
These libraries are © Modular, Inc., distributed as part of the Mojo
toolchain installation on the build host; libstdc++/libgcc_s are
© the GCC project (GPL with the GCC Runtime Library Exception, which
permits linking and redistribution with independent programs). No
other third-party code is bundled.
