// Test-only pinned public-header object layout, no implementation body.
#define GGML_COMMON_DECL_CPP
#include "ggml-common.h"
#include <cstddef>
#include <cstdio>
int main() {
 std::printf("[[10,%d,%zu,%zu,%zu,%zu,%zu],[11,%d,%zu,%zu,%zu,%zu,%zu]]\n",
 QK_K,sizeof(block_q2_K),offsetof(block_q2_K,scales),offsetof(block_q2_K,qs),offsetof(block_q2_K,data.data.d),offsetof(block_q2_K,data.data.dmin),
 QK_K,sizeof(block_q3_K),offsetof(block_q3_K,hmask),offsetof(block_q3_K,qs),offsetof(block_q3_K,scales),offsetof(block_q3_K,d));
}
