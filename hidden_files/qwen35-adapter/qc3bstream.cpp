// QC-3b stream builder (llama.cpp side): tokenizes the RAW grade
// prompts ONCE with the SOURCE model's own tokenizer and takes the
// SOURCE model's greedy 16, so the graded streams are raw token IDs
// from the start (QC-4 witness lesson). No chat template is applied.
// Usage: qc3bstream <source.gguf> <streams.txt> <prompts.txt> <n_threads>
#include "llama.h"
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <string>
#include <vector>
#include <fstream>

static const char * PROMPTS[] = {
    "The capital of France is",
    "Water is made of hydrogen and",
    "The quick brown fox jumps over the",
    "To make bread, you first need to",
    "The largest planet in our solar system is",
    "Once upon a time, there was a small village",
};
static const int N_PROMPTS = 6;

static int argmax_row(const float * row, int n) {
    int am = 0; for (int i = 1; i < n; i++) if (row[i] > row[am]) am = i;
    return am;
}

int main(int argc, char ** argv) {
    if (argc != 5) { fprintf(stderr, "usage: qc3bstream <gguf> <streams> <prompts> <threads>\n"); return 2; }
    const int n_threads = atoi(argv[4]);
    llama_backend_init();
    llama_model_params mp = llama_model_default_params();
    mp.n_gpu_layers = 0;
    llama_model * model = llama_model_load_from_file(argv[1], mp);
    if (!model) { fprintf(stderr, "QC3BSTREAM_MODEL_LOAD_FAILED\n"); return 1; }
    const llama_vocab * vocab = llama_model_get_vocab(model);
    const int n_vocab = llama_vocab_n_tokens(vocab);
    const llama_token eos = llama_vocab_eos(vocab);
    const bool add_bos = llama_vocab_get_add_bos(vocab);
    fprintf(stderr, "QC3BSTREAM_LOADED n_vocab=%d eos=%d add_bos=%d\n", n_vocab, (int) eos, (int) add_bos);
    std::ofstream sf(argv[2]);
    std::ofstream pf(argv[3]);
    llama_batch batch = llama_batch_init(1, 0, 1);
    for (int pi = 0; pi < N_PROMPTS; pi++) {
        const char * text = PROMPTS[pi];
        int need = llama_tokenize(vocab, text, (int) strlen(text), nullptr, 0, add_bos, true);
        std::vector<llama_token> toks(-need);
        if (llama_tokenize(vocab, text, (int) strlen(text), toks.data(), (int) toks.size(), add_bos, true) < 0) {
            fprintf(stderr, "tokenize failed %d\n", pi); return 1;
        }
        llama_context_params cp = llama_context_default_params();
        cp.n_ctx = 1024; cp.n_batch = 64; cp.n_ubatch = 64;
        cp.n_threads = n_threads; cp.n_threads_batch = n_threads;
        llama_context * ctx = llama_init_from_model(model, cp);
        if (!ctx) { fprintf(stderr, "ctx failed\n"); return 1; }
        llama_token next = -1;
        for (size_t pos = 0; pos < toks.size(); pos++) {
            batch.n_tokens = 1; batch.token[0] = toks[pos]; batch.pos[0] = (llama_pos) pos;
            batch.n_seq_id[0] = 1; batch.seq_id[0][0] = 0; batch.logits[0] = true;
            if (llama_decode(ctx, batch) != 0) { fprintf(stderr, "decode failed\n"); return 1; }
            next = argmax_row(llama_get_logits_ith(ctx, 0), n_vocab);
        }
        std::vector<llama_token> gen;
        llama_pos pos = (llama_pos) toks.size();
        for (int g = 0; g < 16; g++) {
            gen.push_back(next);
            if (next == eos) break;
            batch.n_tokens = 1; batch.token[0] = next; batch.pos[0] = pos++;
            batch.n_seq_id[0] = 1; batch.seq_id[0][0] = 0; batch.logits[0] = true;
            if (llama_decode(ctx, batch) != 0) { fprintf(stderr, "gen decode failed\n"); return 1; }
            next = argmax_row(llama_get_logits_ith(ctx, 0), n_vocab);
        }
        llama_free(ctx);
        for (size_t i = 0; i < toks.size(); i++) { if (i) pf << ' '; pf << toks[i]; }
        pf << '\n';
        bool first = true;
        for (auto t : toks) { if (!first) sf << ' '; sf << t; first = false; }
        for (auto t : gen) { sf << ' ' << t; }
        sf << '\n';
        fprintf(stderr, "PROMPT %d IDS:", pi);
        for (auto t : toks) fprintf(stderr, " %d", t);
        fprintf(stderr, "\nGEN %d IDS:", pi);
        for (auto t : gen) fprintf(stderr, " %d", t);
        fprintf(stderr, "\nGEN %d TEXT BEGIN\n", pi);
        char piece[256];
        for (auto t : gen) { int n = llama_token_to_piece(vocab, t, piece, sizeof(piece), 0, true); if (n > 0) fwrite(piece, 1, n, stderr); }
        fprintf(stderr, "\nGEN %d TEXT END\n", pi);
    }
    llama_batch_free(batch);
    llama_model_free(model);
    llama_backend_free();
    fprintf(stderr, "QC3BSTREAM_DONE\n");
    return 0;
}
