#!/usr/bin/env python3
# PRÓF TEST-ONLY — H145 taxonomy completeness (machine-checked).
#
# Asserts: every named error the Mojo codebase can raise (herror("X")
# anywhere, plus DecodedError("X" constructed names) appears in
# vordr/taxonomy.mojo's taxonomy_entries() EXACTLY once, and every
# taxonomy entry appears in docs/vordr/ERROR_TAXONOMY.md.
#
# Pure-MoJo ships; this file is TESTS ONLY (D8 PRÓF). It never touches
# device nodes.

import re
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]

# 1. Names the codebase can raise.
raised = {}
for mojo in list((REPO / "hailbru").rglob("*.mojo")) + \
           list((REPO / "armvegr").glob("*.mojo")) + \
           list((REPO / "vordr").glob("*.mojo")):
    src = mojo.read_text()
    for m in re.finditer(r'herror\(\s*\n?\s*"([A-Za-z]+)"', src):
        raised.setdefault(m.group(1), set()).add(mojo.name)
    for m in re.finditer(r'DecodedError\(\s*\n?\s*"([A-Za-z]+)"', src):
        raised.setdefault(m.group(1), set()).add(mojo.name)
    # raise herror("X", ...) split across lines with the name on the raise line
    for m in re.finditer(r'raise herror\(\s*\n?\s*"([A-Za-z]+)"', src):
        raised.setdefault(m.group(1), set()).add(mojo.name)

# 2. Taxonomy entries.
tax_src = (REPO / "vordr" / "taxonomy.mojo").read_text()
tax_names = re.findall(r'TaxEntry\("([A-Za-z.]+)"', tax_src)

# 3. Doc entries: every taxonomy name must appear verbatim in the doc
# (the doc groups some names on shared lines, so substring is the
# honest check).
doc = (REPO / "docs" / "vordr" / "ERROR_TAXONOMY.md").read_text()

errors = []

# Every raised name: exactly one taxonomy entry.
for name in sorted(raised):
    # DecodedError informational names (not errors) are exempt.
    if name in ("PciStatus.DevselTiming", "PciStatus.FastBackToBack",
                "PciStatus.Cap66MHz", "PciStatus.CapabilitiesList",
                "PciStatus.InterruptStatus", "Pmcsr.PmeEn"):
        continue
    count = tax_names.count(name)
    if count == 0:
        errors.append(f"RAISED-BUT-UNCLASSIFIED: {name} "
                      f"(from {sorted(raised[name])})")
    elif count > 1:
        errors.append(f"DUPLICATE taxonomy entry: {name} x{count}")

# Every taxonomy entry: in the doc.
for name in tax_names:
    if name not in doc:
        errors.append(f"TAXONOMY-NOT-IN-DOC: {name}")

# Every taxonomy entry unique.
if len(tax_names) != len(set(tax_names)):
    dupes = sorted({n for n in tax_names if tax_names.count(n) > 1})
    errors.append(f"DUPLICATE taxonomy entries: {dupes}")

print(f"raised names: {len(raised)}, taxonomy entries: {len(tax_names)}")
if errors:
    print("FAIL:")
    for e in errors:
        print("  " + e)
    sys.exit(1)
print("H145 taxonomy completeness: PASS")
