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

all_quarantined = []
for cf in sorted(class_files):
    cname = os.path.basename(cf).replace('.json', '')
    with open(cf, 'r', encoding='utf-8') as f:
        cdata = json.load(f)
    for lvl, flist in cdata.get('features_by_level', {}).items():
        for feat in flist:
            fid = feat.get('id')
            effects = feat.get('effects', [])
            if fid not in curated_keys and len(effects) == 0:
                all_quarantined.append((cname, int(lvl), fid, feat.get('name')))

print(f"Total quarantined in JSONs: {len(all_quarantined)}")

with open('docs/quarantined_features_remediation_plan.md', 'r', encoding='utf-8') as f:
    plan_text = f.read()

# Find all feature IDs in table rows in section 4
table_row_pattern = r'\|\s*`([^`]+)`\s*\|\s*(\d+)\s*\|\s*(Tier \d+)\s*\|'
table_matches = re.findall(table_row_pattern, plan_text)
table_fids = [m[0] for m in table_matches]

print(f"Total table matches in plan: {len(table_matches)}")

# Check which quarantined feature IDs from JSON are missing from table_matches
missing_from_tables = []
for cname, lvl, fid, fname in all_quarantined:
    if fid not in table_fids:
        missing_from_tables.append((cname, lvl, fid, fname))

print(f"\nQuarantined features missing from Section 4 markdown tables ({len(missing_from_tables)}):")
for cname, lvl, fid, fname in missing_from_tables:
    # Check if fid is mentioned anywhere in plan_text
    in_text = f"`{fid}`" in plan_text
    print(f"  [{cname}] lvl {lvl}: `{fid}` ('{fname}') -> In document text? {in_text}")

