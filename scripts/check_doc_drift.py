#!/usr/bin/env python3
"""
Documentation Drift & Truth Alignment Validator
------------------------------------------------
Scans active Project Aesir documentation files to ensure no prohibited or unbacked
maturity claims exist without citing a Capability Ledger ID (AES-xxx) or being in historical/vision archive.
"""

import sys
import re
from pathlib import Path

# Active doc paths relative to repository root
ACTIVE_DOCS = [
    "README.md",
    "ARCHITECTURE.md",
    "DATA_FLOW.md",
    "INTERFACE.md",
    "docs/ARCHITECTURE.md",
    "docs/DATA_FLOW.md",
    "docs/DOMAIN_MAP.md",
    "docs/PHILOSOPHY.md",
    "docs/REPO_OVERVIEW.md",
    "docs/SYSTEM_VISION.md",
    "docs/Vision.md",
]

# Words / phrases prohibited in present-tense claims unless tagged with ledger IDs or target disclaimers
PROHIBITED_PRESENT_PATTERNS = [
    (r"\bdrop-in replacement\b", "Unbacked 'drop-in replacement' claim"),
    (r"\bzero VRAM\b", "Unbacked 'zero VRAM' claim"),
    (r"\bproduction-ready\b", "Unbacked 'production-ready' claim"),
    (r"\bPagedAttention\b", "PagedAttention terminology used (must specify contiguous KV cache status)"),
]

def check_doc(repo_root: Path, rel_path: str) -> list[str]:
    filepath = repo_root / rel_path
    if not filepath.exists():
        return [f"File not found: {rel_path}"]
    
    content = filepath.read_text(encoding="utf-8")
    lines = content.splitlines()
    errors = []
    
    for i, line in enumerate(lines, 1):
        # Skip markdown links to historical docs or disclaimers
        if "docs/historical/" in line or "HISTORICAL_" in line or "CAPABILITY_LEDGER.md" in line:
            continue
        
        # Check prohibited patterns if not tagged with an AES-xxx capability ID on the same line or section
        for pattern, desc in PROHIBITED_PRESENT_PATTERNS:
            if re.search(pattern, line, re.IGNORECASE):
                if not re.search(r"AES-[A-Z]+-\d+", line):
                    errors.append(f"{rel_path}:{i}: {desc} -> '{line.strip()}'")
                    
    return errors

def main():
    repo_root = Path(__file__).resolve().parent.parent
    total_errors = []
    
    print("🔍 Running Documentation Drift Check...")
    for doc in ACTIVE_DOCS:
        errors = check_doc(repo_root, doc)
        if errors:
            total_errors.extend(errors)
            
    if total_errors:
        print(f"❌ Documentation Drift Check FAILED with {len(total_errors)} issue(s):")
        for err in total_errors:
            print(f"  - {err}")
        sys.exit(1)
    else:
        print("✅ Documentation Drift Check PASSED: All active docs are aligned with truth boundaries.")
        sys.exit(0)

if __name__ == "__main__":
    main()
