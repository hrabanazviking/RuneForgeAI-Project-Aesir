#!/usr/bin/env python3
"""QS-5.1 worst-case leg: ~3400-token prompt + up to 512-token
generation (total under the 4096 context cap), against the
rehearsal serve on 18438. Reuses qs5_measure's client."""
import qs5_measure as m

msgs = [{"role": "system", "content": m.SYSTEM},
        {"role": "user", "content": m.words_prompt(
            2900, "Question: in one sentence, what filled the manifests?")}]
m.chat(msgs, 512, "prefill-max")
print("PEAKLEG DONE", flush=True)
