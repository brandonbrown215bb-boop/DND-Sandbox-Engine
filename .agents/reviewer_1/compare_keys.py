import re

with open('docs/quarantined_features_remediation_plan.md', 'r', encoding='utf-8') as f:
    text = f.read()

# Collect all feature IDs from table rows matching Tier 1 and Tier 2
t1_t2_pattern = r'\|\s*`([^`]+)`(?:\s*\([^)]+\))?\s*\|\s*(\d+)\s*\|\s*(Tier [12])\s*\|'
t1_t2_matches = re.findall(t1_t2_pattern, text)

# Extract all keys present in all gdscript code blocks including special chars
gdscript_blocks = re.findall(r'```gdscript\s*(.*?)\s*```', text, re.DOTALL)

curated_dict_keys = set()
for block in gdscript_blocks:
    # Match any string inside quotes followed by : {
    keys = re.findall(r'"([^"]+)"\s*:\s*\{', block)
    for k in keys:
        curated_dict_keys.add(k)

print(f"Total Tier 1 & Tier 2 table entries: {len(t1_t2_matches)}")
print(f"Total keys in GDScript snippets: {len(curated_dict_keys)}")

table_fids = set(m[0] for m in t1_t2_matches)

missing_in_snippets = table_fids - curated_dict_keys
extra_in_snippets = curated_dict_keys - table_fids

print("\nTable Tier 1/2 feature IDs missing from GDScript snippet keys:")
for fid in sorted(missing_in_snippets):
    print(f"  - `{fid}`")

print("\nSnippet keys not matching any Tier 1/2 table feature ID:")
for key in sorted(extra_in_snippets):
    print(f"  - `{key}`")

