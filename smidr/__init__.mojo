# SMIÐR — clean-room chip-configuration generation (D3).
#
# SMIÐR generates chip-executable configurations for the Hailo-10 WITHOUT
# the proprietary Dataflow Compiler, from clean-room findings only
# (docs/plunder/). L5 binds every file here: studied vendor sources are
# understanding-only; nothing is copied, translated, or vendored.
#
# Modules:
#   mailbox    — firmware mailbox submission primitive (H102): command
#                slot write, ready-flag doorbell, completion poll, response
#                read. The ONLY module besides hailbru that touches BARs,
#                and only through hailbru.regs (L12: hailbru owns device
#                nodes/BARs; smidr.mailbox is its authorized client).
#   descriptor — minimal command descriptor builder (H103).
#   config_gen — tiny vector-add / matmul configuration generator
#                (H104/H107).
