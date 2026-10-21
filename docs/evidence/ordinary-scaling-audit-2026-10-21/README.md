# Ordinary scaling configuration audit

48 pinned public metadata constructor cases plus48 isolated constant cases/120
linear Float32 words, with unchanged license/module
identities. The constructor process imports no Torch/model module; the separate tiny
constant process imports Torch and blocks module/attention forwards. No source
weights, model/layer/attention forward, network or Hailo access. Original input, caller-after, selected result and
warnings retained. Legacy type can overwrite rope_type/caller data; warning-bearing
constructor results do not prove mathematical validity. pretraining_tp remains
metadata with unqualified execution semantics. Float32 constant results are not
native/source64/device numerical acceptance. Full syscall traces stay outside
Git with exact identity/mode. No native scaling or hardware capability claim.
