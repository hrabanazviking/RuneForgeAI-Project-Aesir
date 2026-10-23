# Original grouped USERPTR launch value codec

Date:2026-10-23. Publish before production. Parent:
`TASK_hailo10h_program_delivery.md`. Qualified fields:
`docs/HAILO10H_GROUPED_TRANSFER_BOUNDARY_2026-10-23.md`. Fixed owner scope:
`docs/HAILO10H_OWNER_NATIVE_SCOPE_2026-10-20.md`.

Add ONLY original `hailbru/soc_group.mojo`,bounded diagnostic and scoped tests;
zero old production/test edits. Represent copied USERPTR spans with unsigned
address/size values and an owned group carrying channel,descriptor handle and
span list. Encode/decode canonical141-byte launch intent for one through eight
ordered spans. Use published count/array/field offsets;reuse existing original
soc_abi checked integer/channel/handle/length/zero-buffer helpers. No vendor
implementation,parser/bit/OS algorithm copy or new raw OS interface.

Initial canonical profile is engine0,debug false,noncyclic,USERPTR type0,zero
unused slots. These are explicit codec choices,not permanent model/hardware
eligibility restrictions. Validate all spans and the actual list count before
allocation. Require nonzero pointer and positive UInt32 size,checked unsigned
address+extent,valid existing channel/descriptor-handle values. Do not infer
alignment,physical mapping,pinning or safe addresses from scalars. Decode exact
extent,known profile,count and unused-slot zeros;do not trust cached counts or
unchecked offsets. Guard every mutable field at use. Return independent copied
spans/bytes with correct copy/move/source lifetimes.

No mapping,cache sync,driver.request,ioctl,device/network access or integration
with live SocRpcClient. Do not emit a physical metadata/program transaction.
Physical grouped DMA,descriptor accounting,read-only/sealed program storage,
in-flight lifetime,total deadlines and failure cleanup need separate established
contracts. No numerical opcode,register,resource budget,program admission or
source-model execution is implied. All LLM execution remains Hailo-10H only.

Before code reverify actual684 Mojo/78 Python copies,134 frozen controls and
unchanged compiler against the published contract. Build all new consumers and
selected existing ABI consumers,with any supplementary originals built/frozen
before production when absent from those134 controls. Freeze all linked inputs
before acceptance. Independently compile the pinned public-header object oracle
and compare complete bytes for every supported count and every slot. Cross-check
one-buffer compatible-domain bytes with the frozen original soc_transfer helper;
retain any deliberately stricter checked-extent refusal as scoped behavior.

Cover zeros/maxima/asymmetric/walking-bit spans,group order,list replacement,
count/slot/flags/unused-state mutations,all truncations/trailing extents,integer
and pointer overflow,ownership/copy/move and refusal/fresh-success cycles. Use
synthetic addresses only;never dereference them. Rerun the selected original ABI
suite and pair complete stdout/stderr/exit for every invoked frozen consumer.
Trace new consumers for device/network/ioctl/process/runtime effects;inspect ELF
separately. Preserve failures and raw source/test/control copies;no whole-repo or
CI claim. Verify->publish Hailo->exact remote head/tree->FF main preserving owner
work->verify clean->continue actual numerical/physical/program work.

The broad ordinary UNMODIFIED model target100% stays fixed. Missing format,
architecture,operation,numerical/physical configuration,program delivery and
hardware result/cleanup remain required implementation. No DFC,outside model
compiler/machine,precompiled-model prerequisite,CPU/CUDA/cloud LLM/proxy,guessed
opcode/register/write,reset/rebind or firmware/kernel change.
