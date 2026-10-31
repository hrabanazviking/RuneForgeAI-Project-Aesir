import gguf
M = "/home/volmarr/aesir-gpu/.aesir/models/olmoe-1b-7b-0924-instruct-q4_k_m.gguf"
r = gguf.GGUFReader(M)
toks = r.fields["tokenizer.ggml.tokens"].contents()
bs = list(range(ord("!"), ord("~") + 1)) + list(range(0xA1, 0xAC + 1)) + list(range(0xAE, 0xFF + 1))
cs = bs[:]; n = 0
for b in range(256):
    if b not in bs:
        bs.append(b); cs.append(256 + n); n += 1
inv = {chr(c): b for b, c in zip(bs, cs)}
def dec(idlist):
    raw = bytearray()
    for i in idlist:
        for ch in toks[i]:
            if ch in inv: raw.append(inv[ch])
            else: raw.extend(ch.encode("utf-8"))
    return bytes(raw).decode("utf-8", errors="replace")
ids = [int(x) for x in open("/home/volmarr/j022/prompt_prose_ids.csv").read().strip().split(",")]
for N in range(2, 8):
    with open(f"/home/volmarr/j022/b1/prompt_{N}.txt", "w") as f:
        f.write(dec(ids[:N]))
    print(N, repr(dec(ids[:N])))
