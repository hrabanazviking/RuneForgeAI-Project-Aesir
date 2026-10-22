// Test-only pinned public-header object layout; no vendor implementation body.
#define GGML_COMMON_DECL_CPP
#include "ggml-common.h"
#include <cstddef>
#include <cstdio>

int main() {
    std::printf("[[2,%d,%zu,%zu,-1,-1,%zu],"
                "[3,%d,%zu,%zu,%zu,-1,%zu],"
                "[6,%d,%zu,%zu,-1,%zu,%zu],"
                "[7,%d,%zu,%zu,%zu,%zu,%zu]]\n",
        QK4_0, sizeof(block_q4_0), offsetof(block_q4_0,d), offsetof(block_q4_0,qs),
        QK4_1, sizeof(block_q4_1), offsetof(block_q4_1,data.data.d), offsetof(block_q4_1,data.data.m), offsetof(block_q4_1,qs),
        QK5_0, sizeof(block_q5_0), offsetof(block_q5_0,d), offsetof(block_q5_0,qh), offsetof(block_q5_0,qs),
        QK5_1, sizeof(block_q5_1), offsetof(block_q5_1,data.data.d), offsetof(block_q5_1,data.data.m), offsetof(block_q5_1,qh), offsetof(block_q5_1,qs));
}
