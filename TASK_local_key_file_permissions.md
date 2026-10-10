# AES500-371 — local key-file permission contract

## Objective and owner

Strengthen executable evidence for service-key creation and admission across
POSIX permission modes. The owners are `server/keyfiles.mojo`,
`server/local_transport.mojo`, and the native key/service probes.

## Invariants

- New key files are created without group/world permissions, independent of a
  permissive process umask.
- Service admission accepts only a regular file owned by the effective user
  and rejects every group/world permission bit before model/CUDA access.
- Symlinks and FIFOs remain rejected; permissions of the linked target are
  never treated as permission to follow a symlink.
- The tests assert rejected keys fail before accelerator initialization and
  never print key contents.

## Acceptance and exclusions

Exercise creation under umask `000`, owner-only mode, a representative matrix
of group/world read/write/execute bits, symlink/FIFO rejection, and the existing
publication race. Do not change the existing permission policy unless evidence
finds a defect. This is local POSIX evidence, not Windows ACL validation.
