# Fixed owner target: Mojo source-model execution on Hailo-10H

Date: 2026-10-19. Status: contract before implementation.

## Immutable objective

The owner requires Project Aesir in Mojo to run source models of the right
size for this Hailo hardware. The owner explicitly forbids changing that
target and rejects limiting the product to compatible precompiled models.
Only an explicit owner instruction may revise the objective. An unresolved
technical barrier is not authorization to substitute a narrower product.

The existing vendor-precompiled GenAI smoke receipts remain historical
observations. They do not satisfy the source-model compilation/execution goal.
No further vendor catalog selection is authorized as a substitute for that
goal. Preserve those artifacts and evidence without building the roadmap
around their restriction.

## Immediate work

1. Inspect the existing Mojo loaders, model representation, compute lowering,
   SMIÐR configuration generator, and HAILBRÚ transport. Reconcile actual code
   against the historic H019/H102/H111 evidence and identify exact missing
   connections to execute a source model on the device.
2. Publish a bounded implementation slice that advances the real source-model
   path: model import/representation, operation coverage/lowering, device
   program generation, or verified transport, according to the observed
   dependency frontier. Do not invent undocumented device encodings.
3. Make supported format/architecture and memory evidence explicit while
   retaining the broad owner objective. Incremental coverage does not redefine
   the final target or allow unsupported operations to be called supported.
4. Reconcile remaining work orders that currently assume vendor-precompiled
   artifacts before executing them. Historical completion flags cannot waive
   the missing source-model pipeline.

Host model parsing, compilation, orchestration and data movement may use the
Pi CPU. LLM inference stays on Hailo-10H. CPU/CUDA/cloud inference and inference
proxies remain outside the target. Preserve model bytes, existing source,
owner changes and all negative results. Kernel rebuilds, firmware changes and
device rebinding require their existing explicit operator authorization.

## Automatic workflow and acceptance

The owner authorizes completing a slice, verifying it, publishing it to
`docs/cross-cutting-hailo-mission`, checking the remote revision, and immediately
starting the next slice without another continuation request.

Each implementation slice must name its actual consumer, invariants, physical
or independent acceptance evidence, and unresolved dependencies. Documentation,
host primitives, a vendor-precompiled demo, and model memory fit alone do not
prove end-to-end source-model execution. Report the actual gap and continue
work toward the same target. Never declare completion of a substituted goal.
