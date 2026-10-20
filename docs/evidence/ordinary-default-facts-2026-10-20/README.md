# Ordinary default semantic facts

Read ../../HAILO10H_ORDINARY_DEFAULTS_DESIGN.md for scope and exact defaults.
Pinned4.57.1 public configuration constructors only,31 input/output cases,
license/module/environment identities and syscall proof. No Torch is installed
in that isolated test environment; no model/weights/tensor/attention execution,
network or device is used. The installed5.7 probe imported Torch and failed its
isolation guard; preserve its evidence, do not claim it was isolated. It did
not instantiate a model/weights or request inference/network/device work.

No external implementation source is redistributed: probe scripts are original
public API callers and reports are metadata facts. The oracle environment is
outside the production tree; no Aesir runtime or user dependency is introduced.
Raw traces retain observed machine/package paths. These facts alone do not
establish source rotary pairing or numerical Hailo execution.
