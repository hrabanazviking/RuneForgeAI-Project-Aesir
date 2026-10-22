// Test-only immutable public-header layout object. No runtime/model API.
#include <cstddef>
#include <cstdio>
#define GGML_COMMON_DECL_CPP
#include "ggml.h"
#include "ggml-common.h"
int main() {
    std::printf("[[%d,%d,%zu,%zu,%zu,%zu,%zu],[%d,%d,%zu,%zu,%zu,%zu,%zu]]\n",
        GGML_TYPE_Q2_K,QK_K,sizeof(block_q2_K),offsetof(block_q2_K,scales),offsetof(block_q2_K,qs),offsetof(block_q2_K,data.data.d),offsetof(block_q2_K,data.data.dmin),
        GGML_TYPE_Q3_K,QK_K,sizeof(block_q3_K),offsetof(block_q3_K,hmask),offsetof(block_q3_K,qs),offsetof(block_q3_K,scales),offsetof(block_q3_K,d));
}
