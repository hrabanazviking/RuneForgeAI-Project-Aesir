// QC-4 cross-grade tool (llama.cpp side): teacher-forcing FULL logit
// rows on RAW token IDs + greedy witness, CPU only.
// Pattern: the Q35-3b q35grade comparator (~/llama.cpp-build/q35grade),
// extended to dump every logit row (vocab 512: rows are tiny) so the
// cross-grade rank/gap account can be computed exactly, and to run
// the greedy witness on ALL prompts (16 tokens, QC-3a convention).
// This tool never tokenizes prompt text and never applies a template:
// token streams come from files written from the QC-3a banked grade
// log (tokenized ONCE by the Aesir source model's own tokenizer).
// Usage: qc4grade <model.gguf> <streams.txt> <prompts.txt> <rows.bin> <gen.txt> <n_threads>
//   streams.txt: one FULL graded stream per line (prompt + source greedy 16)
//   prompts.txt: one prompt-prefix stream per line (same order)
//   rows.bin: int32 n_prompts, int32 n_vocab; per prompt int32 n_rows,
//             then n_rows*n_vocab float32 rows (row after tokens[pos])
#include "llama.h"
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <string>
#include <vector>
#include <fstream>
#include <sstream>

static std::vector<std::vector<llama_token>> read_tokens(const char * path) {
    std::ifstream in(path);
    std::vector<std::vector<llama_token>> prompts;
    std::string line;
    while (std::getline(in, line)) {
        if (line.empty()) continue;
        std::vector<llama_token> p;
        std::istringstream ss(line);
        long long v;
        while (ss >> v) p.push_back((llama_token) v);
        if (!p.empty()) prompts.push_back(p);
    }
    return prompts;
}

static int argmax_row(const float * row, int n) {
    int am = 0; for (int i = 1; i < n; i++) if (row[i] > row[am]) am = i;
    return am;
}

int main(int argc, char ** argv) {
    if (argc != 7) { fprintf(stderr, "usage: qc4grade <gguf> <streams> <prompts> <rows.bin> <gen.txt> <threads>\n"); return 2; }
    const int n_threads = atoi(argv[6]);
    auto streams = read_tokens(argv[2]);
    auto prompts = read_tokens(argv[3]);
    if (streams.empty() || streams.size() != prompts.size()) { fprintf(stderr, "stream/prompt count mismatch\n"); return 2; }
    llama_backend_init();
    llama_model_params mp = llama_model_default_params();
    mp.n_gpu_layers = 0;
    llama_model * model = llama_model_load_from_file(argv[1], mp);
    if (!model) { fprintf(stderr, "QC4GRADE_MODEL_LOAD_FAILED\n"); return 1; }
    const llama_vocab * vocab = llama_model_get_vocab(model);
    const int n_vocab = llama_vocab_n_tokens(vocab);
    const llama_token eos = llama_vocab_eos(vocab);
    fprintf(stderr, "QC4GRADE_LOADED n_vocab=%d eos=%d prompts=%zu\n", n_vocab, eos, streams.size());
    FILE * bin = fopen(argv[4], "wb");
    if (!bin) { fprintf(stderr, "cannot open rows.bin\n"); return 2; }
    int32_t np = (int32_t) streams.size();
    fwrite(&np, 4, 1, bin);
    fwrite(&n_vocab, 4, 1, bin);
    FILE * gf = fopen(argv[5], "w");
    llama_batch batch = llama_batch_init(1, 0, 1);
    for (size_t pi = 0; pi < streams.size(); pi++) {
        llama_context_params cp = llama_context_default_params();
        cp.n_ctx = 1024; cp.n_batch = 64; cp.n_ubatch = 64;
        cp.n_threads = n_threads; cp.n_threads_batch = n_threads;
        llama_context * ctx = llama_init_from_model(model, cp);
        if (!ctx) { fprintf(stderr, "ctx failed\n"); return 1; }
        const auto & toks = streams[pi];
        int32_t n_rows = (int32_t) toks.size() - 1;
        fwrite(&n_rows, 4, 1, bin);
        for (size_t pos = 0; pos + 1 < toks.size(); pos++) {
            batch.n_tokens = 1;
            batch.token[0] = toks[pos];
            batch.pos[0] = (llama_pos) pos;
            batch.n_seq_id[0] = 1;
            batch.seq_id[0][0] = 0;
            batch.logits[0] = true;
            if (llama_decode(ctx, batch) != 0) { fprintf(stderr, "decode failed at %zu %zu\n", pi, pos); return 1; }
            const float * row = llama_get_logits_ith(ctx, 0);
            fwrite(row, 4, n_vocab, bin);
        }
        llama_free(ctx);
        // greedy witness: fresh context, prompt prefix only, 16 tokens
        llama_context * gctx = llama_init_from_model(model, cp);
        if (!gctx) { fprintf(stderr, "gen ctx failed\n"); return 1; }
        const auto & pre = prompts[pi];
        llama_token next = -1;
        for (size_t pos = 0; pos < pre.size(); pos++) {
            batch.n_tokens = 1;
            batch.token[0] = pre[pos];
            batch.pos[0] = (llama_pos) pos;
            batch.n_seq_id[0] = 1;
            batch.seq_id[0][0] = 0;
            batch.logits[0] = true;
            if (llama_decode(gctx, batch) != 0) { fprintf(stderr, "gen prompt decode failed\n"); return 1; }
            next = argmax_row(llama_get_logits_ith(gctx, 0), n_vocab);
        }
        std::vector<llama_token> gen;
        llama_pos pos = (llama_pos) pre.size();
        for (int g = 0; g < 16; g++) {
            gen.push_back(next);
            if (next == eos) break;
            batch.n_tokens = 1;
            batch.token[0] = next;
            batch.pos[0] = pos++;
            batch.n_seq_id[0] = 1;
            batch.seq_id[0][0] = 0;
            batch.logits[0] = true;
            if (llama_decode(gctx, batch) != 0) { fprintf(stderr, "gen decode failed\n"); return 1; }
            next = argmax_row(llama_get_logits_ith(gctx, 0), n_vocab);
        }
        fprintf(gf, "GEN %zu IDS:", pi);
        for (auto t : gen) fprintf(gf, " %d", t);
        fprintf(gf, "\nGEN %zu TEXT BEGIN\n", pi);
        char piece[256];
        for (auto t : gen) {
            int n = llama_token_to_piece(vocab, t, piece, sizeof(piece), 0, true);
            if (n > 0) fwrite(piece, 1, n, gf);
        }
        fprintf(gf, "\nGEN %zu TEXT END\n", pi);
        llama_free(gctx);
        fprintf(stderr, "prompt %zu done (stream %zu tokens, gen %zu)\n", pi, toks.size(), gen.size());
    }
    fclose(bin);
    fclose(gf);
    llama_batch_free(batch);
    llama_model_free(model);
    llama_backend_free();
    fprintf(stderr, "QC4GRADE_DONE\n");
    return 0;
}
