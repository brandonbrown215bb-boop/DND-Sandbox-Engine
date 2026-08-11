import re

with open('docs/quarantined_features_remediation_plan.md', 'r', encoding='utf-8') as f:
    text = f.read()

# Collect all feature IDs from table rows matching Tier 1 and Tier 2
t1_t2_pattern = r'\|\s*`([^`]+)`(?:\s*\([^)]+\))?\s*\|\s*(\d+)\s*\|\s*(Tier [12])\s*\|'
t1_t2_matches = re.findall(t1_t2_pattern, text)

print(f"Total Tier 1 & Tier 2 features across all class tables: {len(t1_t2_matches)}")

# Extract all keys present in all gdscript code blocks
gdscript_blocks = re.findall(r'```gdscript\s*(.*?)\s*```', text, re.DOTALL)

curated_dict_keys = set()
for block in gdscript_blocks:
    keys = re.findall(r'"([a-zA-Z0-9_\'-]+)"\s*:\s*\{', block)
    for k in keys:
        curated_dict_keys.add(k)

print(f"Total distinct feature keys in GDScript code blocks: {len(curated_dict_keys)}")

missing_snippets = []
for fid, lvl, tier in t1_t2_matches:
    if fid not in curated_dict_keys:
        missing_snippets.append((fid, lvl, tier))

if missing_snippets:
    print(f"\nTier 1 / Tier 2 Features missing from GDScript snippets ({len(missing_snippets)}):")
    for fid, lvl, tier in missing_snippets:
        print(f"  - `{fid}` (Level {lvl}, {tier})")
else:
    print("\nSUCCESS! Every single Tier 1 and Tier 2 feature has a corresponding proposed GDScript snippet in Section 4!")

