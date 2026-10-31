// J-022 B1: tokenization dump for the tf_oracle comparator path.
// Loads the model exactly as tf_oracle.c does, tokenizes the prompt
// file with the identical call (add_special=false, parse_special=true,
// trailing newlines stripped), and prints the token ids so they can be
// compared id-for-id with the ids fed to the Aesir session -- the
// J-022 grade verified only the COUNT (67 == 67), never the ids.
// Usage: tf_tokdump <gguf> <promptfile>
#include "llama.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

int main(int argc, char ** argv) {
    if (argc != 3) { fprintf(stderr, "usage: tf_tokdump <gguf> <promptfile>\n"); return 2; }
    FILE * f = fopen(argv[2], "rb");
    if (!f) { perror("prompt"); return 2; }
    fseek(f, 0, SEEK_END); long flen = ftell(f); fseek(f, 0, SEEK_SET);
    char * prompt = malloc(flen + 1);
    if (fread(prompt, 1, flen, f) != (size_t) flen) { return 2; }
    fclose(f);
    while (flen > 0 && prompt[flen-1] == '\n') flen--;
    prompt[flen] = 0;

    llama_backend_init();
    struct llama_model_params mp = llama_model_default_params();
    struct llama_model * model = llama_model_load_from_file(argv[1], mp);
    if (!model) { fprintf(stderr, "load failed\n"); return 1; }
    const struct llama_vocab * vocab = llama_model_get_vocab(model);

    int cap = flen + 64;
    llama_token * toks = malloc(sizeof(llama_token) * cap);
    int n_tok = llama_tokenize(vocab, prompt, flen, toks, cap, false, true);
    fprintf(stderr, "prompt_tokens=%d\n", n_tok);
    for (int i = 0; i < n_tok; i++) {
        printf("%s%d", i ? "," : "", toks[i]);
    }
    printf("\n");
    return 0;
}
