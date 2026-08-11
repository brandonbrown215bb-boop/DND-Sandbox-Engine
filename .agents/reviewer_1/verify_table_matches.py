import json
import glob
import os
import re

classes_dir = 'data/core/classes'
with open('src/autoload/data_loader.gd', 'r', encoding='utf-8') as f:
    dl_content = f.read()

start_idx = dl_content.find('const CURATED_FEATURE_EFFECTS := {')
end_idx = dl_content.find('\n}', start_idx) + 2
curated_block = dl_content[start_idx:end_idx]
curated_keys = set(re.findall(r'"([^"]+)":\s*\{', curated_block))

class_files = glob.glob(os.path.join(classes_dir, '*.json'))

all_quarantined_entries = []
for cf in sorted(class_files):
    cname = os.path.basename(cf).replace('.json', '')
    with open(cf, 'r', encoding='utf-8') as f:
        cdata = json.load(f)
    for lvl, flist in cdata.get('features_by_level', {}).items():
        for feat in flist:
            fid = feat.get('id')
            effects = feat.get('effects', [])
            if fid not in curated_keys and len(effects) == 0:
                all_quarantined_entries.append((cname, int(lvl), fid, feat.get('name')))

with open('docs/quarantined_features_remediation_plan.md', 'r', encoding='utf-8') as f:
    plan_text = f.read()

# Pattern matching column 1 with optional (L1)/(L2) annotations
row_pattern = r'\|\s*`([^`]+)`(?:\s*\([^)]+\))?\s*\|\s*(\d+)\s*\|\s*(Tier \d+)\s*\|'
table_matches = re.findall(row_pattern, plan_text)

print(f"Total quarantined entries in JSON: {len(all_quarantined_entries)}")
print(f"Total matching table rows in plan: {len(table_matches)}")

# Count tiers in table matches
tier_counts = {}
for fid, lvl, tier in table_matches:
    tier_counts[tier] = tier_counts.get(tier, 0) + 1

print("\nTier Breakdown in Section 4 Tables:", sorted(tier_counts.items()))

# Check each entry
missing_entries = []
for cname, lvl, fid, fname in all_quarantined_entries:
    # Look for matching (fid, lvl) in table_matches
    match_found = False
    for m_fid, m_lvl, m_tier in table_matches:
        if m_fid == fid and int(m_lvl) == lvl:
            match_found = True
            break
    if not match_found:
        missing_entries.append((cname, lvl, fid, fname))

if missing_entries:
    print(f"\nMissing ({len(missing_entries)}):")
    for cname, lvl, fid, fname in missing_entries:
        print(f"  [{cname}] lvl {lvl}: `{fid}` ({fname})")
else:
    print("\nSUCCESS! Every single one of the 157 quarantined class feature level entries is accounted for in Section 4 tables!")

