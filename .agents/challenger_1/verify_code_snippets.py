import json
import re
from pathlib import Path

ROOT = Path("c:/Users/brand/Documents/linux/Top Down Party Game")
DOC_PATH = ROOT / "docs" / "quarantined_features_remediation_plan.md"

doc_text = DOC_PATH.read_text(encoding="utf-8")

# Extract GDScript code blocks from the doc
code_blocks = re.findall(r'```gdscript\s*(.*?)\s*```', doc_text, re.DOTALL)
print(f"Total ```gdscript``` code blocks found in doc: {len(code_blocks)}")

# Let's inspect the contents of code blocks to see what keys they define
defined_keys = set()
invalid_blocks = []

for idx, block in enumerate(code_blocks, 1):
    # Try parsing keys like "feature_id": { ... }
    matches = re.findall(r'"([a-zA-Z0-9_:]+)":\s*\{', block)
    for m in matches:
        defined_keys.add(m)

print(f"Total distinct feature keys specified in GDScript code blocks: {len(defined_keys)}")
print("\nKeys specified in code blocks:")
for k in sorted(defined_keys):
    print(f"  - {k}")

