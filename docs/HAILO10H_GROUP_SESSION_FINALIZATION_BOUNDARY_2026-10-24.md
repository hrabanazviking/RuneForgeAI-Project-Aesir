# Same-file grouped ownership: cleanup interface boundary

Date:2026-10-24. Continued automatically after original observed progress
publication77acc166eb123c8b7fad9df9cbc7b3bebf10adb8. Research parent:
`TASK_hailo10h_program_delivery.md`. Fixed broad ordinary UNMODIFIED source-model
support100% remains controlled by`HAILO10H_OWNER_NATIVE_SCOPE_2026-10-20.md`.

The pinned public driver revision remains
`45e5fc53c6922fd6985febfc09399653497a2082`. Full root GPL2 and common MIT
licenses were read before seven selected source bodies. All seven installed
source files match the public Git blob identities. Fresh read-only kernel,
module version/source-version and live/file build-ID metadata agree with the
previous profile:kernel6.12.112-v8-16k-hailo+,driver5.3.0,source-version
91195A5A35A8DAAA5717B7D,build-ID380557783212772d9b067ff0163631a222c26d64.
Installed module SHA-256 remains
756d58f7ffb51ca5999e09b7ae14b422b3b0450cf29d2cdabf8babc9491481e4.
This is identity metadata and selected source equivalence,not a reproducible
binary/firmware equivalence proof. No source algorithm is copied or translated.

## Caller and cleanup facts

The normal [file release path](https://github.com/hailo-ai/hailort-drivers/blob/45e5fc53c6922fd6985febfc09399653497a2082/linux/pcie/src/fops.c#L181)
finalizes a valid file context under the board mutex. Its context finalizer
invokes SoC cleanup before VDMA cleanup. The release path then frees context
and returns0;it does not propagate a remote-channel close result.

The [SoC close path](https://github.com/hailo-ai/hailort-drivers/blob/45e5fc53c6922fd6985febfc09399653497a2082/linux/pcie/src/soc.c#L204)
validates that requested channels belong to that file,requests channel stop
before remote close,and only clears its ownership bitmap after success.
The file finalizer calls the same close helper but discards its result.
Consequently,typed close failure and successful file-context release do not
establish successful remote logical closure in every failure case.

The [stop helper](https://github.com/hailo-ai/hailort-drivers/blob/45e5fc53c6922fd6985febfc09399653497a2082/common/vdma_common.c#L801)
returns void. An idle timeout is logged,then abort is still requested. There is
no returned idle-result field for our owner to validate. Software cleanup and
hardware idle confirmation must remain distinct. No new register/opcode or
independent channel-stop implementation follows from reading these bodies.

The [VDMA context finalizer](https://github.com/hailo-ai/hailort-drivers/blob/45e5fc53c6922fd6985febfc09399653497a2082/linux/vdma/vdma.c#L254)
disables its enabled channel state,then clears mapped buffers,descriptor lists
and continuous buffers. Software channel disable drains ongoing records through
transfer completion/release and clears bookkeeping. The Linux release hook
requests CPU sync and drops transfer references. This is an interface cleanup
sequence,not evidence that a device numerically completed the transfer.

[Memory cleanup](https://github.com/hailo-ai/hailort-drivers/blob/45e5fc53c6922fd6985febfc09399653497a2082/linux/vdma/memory.c#L415)
destroys mapped objects and releases USERPTR scatter-gather page references.
Descriptor release frees its prepared-queue storage and descriptor allocation.
The queue-storage free helper is distinct from the explicit prepared cancellation
loop,which releases prepared-transfer references. Neither operation establishes
that already launched DMA became idle. No borrowed queue/counting policy is used.

## Consequence for original Mojo work

Next original same-file owner must retain the two actual sealed backing fds and
views through session cleanup,distinguish any cleanup error from an unconfirmed
file close,and permanently retain/poison resources on uncertain finalization.
No extra mapping release may follow an assumed cancellation result. A successful
file-context close may be reported as that software event;it must not be renamed
an all-failure hardware-idle or remote-cleanup confirmation.

The next bounded native contract is`TASK_hailo10h_session_transfer_pin.md`:
original same-file channel/list plus existing two-part sealed mapping ownership,
with host faults and actual kernel fd/VMA observations. It permits no physical
session/connect/map/prepare/launch. A live control-RPC experiment needs a later
contract and explicit completion/error/late-cleanup boundaries. No arbitrary
transaction split or action2/program activation is justified by this study.

This report grants no native capability or numerical execution. Actual numerical
configuration,precision/packing,placement,original program activation/results
and broad remaining source-model implementation remain required. All eventual
LLM execution stays Hailo-10H;DFC,external compilers/machines,precompiled
prerequisites and host/CUDA/cloud inference or proxies remain excluded.

Retained raw evidence:`evidence/group-session-finalization-2026-10-24/` pins
827 paths/6347569 aggregate bytes,including seven actual
source files,licenses,read-only query results and the next contract's fresh
711 Mojo/88 test copies and161 control identities. Manifest SHA-256:
`49b6fef59119b58a9c5eeba32b064499430f857f7b08d88cbc6c2dd4a84d4d4a`. All paths were rehashed before publication.

Publication review reverified all827 raw identities. The nine inherited schema
errors and23757 existing drift findings remain identical;no new drift finding
or capability entry is introduced. Current census stays142 verified/187 total.
These are repository consistency observations,not a whole-repository pass.
