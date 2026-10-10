# HAILBRU tools subpackage (Campaign 5).
#
# Makes hailbru/tools/ a proper Mojo package so that entry files inside
# it (probe.mojo, api_surface_test.mojo) resolve `from hailbru.*`
# imports: Mojo's module search walks up through package directories,
# and a directory without __init__.mojo breaks the walk. Discovered
# 2026-10-10 when `mojo build hailbru/tools/probe.mojo` failed with
# "unable to locate module 'hailbru'" until this file was added.
