// Isolated public-header object; no external implementation or runtime API.
#define GGML_COMMON_DECL_CPP
#include "ggml-common.h"
#include <cstddef>
#include <cstdio>
int main() {
 std::printf("[[20,%d,%zu,%zu,%zu],[23,%d,%zu,%zu,%zu,%zu,%zu]]\n",
 QK4_NL,sizeof(block_iq4_nl),offsetof(block_iq4_nl,d),offsetof(block_iq4_nl,qs),
 QK_K,sizeof(block_iq4_xs),offsetof(block_iq4_xs,d),offsetof(block_iq4_xs,scales_h),offsetof(block_iq4_xs,scales_l),offsetof(block_iq4_xs,qs));
}
