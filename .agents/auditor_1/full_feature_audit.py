import json
import glob
import os
import re

with open('docs/quarantined_features_remediation_plan.md', 'r', encoding='utf-8') as f:
    doc_text = f.read()

with open('src/generate_feature_matrix.py', 'r', encoding='utf-8') as f:
    matrix_code = f.read()

import ast
curated_dict_match = re.search(r'CURATED_FEATURE_EFFECTS = (\{.*?\n\})', matrix_code, re.DOTALL)
CURATED_FEATURE_EFFECTS = ast.literal_eval(curated_dict_match.group(1)) if curated_dict_match else {}

class_files = sorted(glob.glob('data/core/classes/*.json'))

all_json_features = []
all_quarantined_json_features = []

for cf in class_files:
    cname = os.path.basename(cf).replace('.json', '')
    with open(cf, 'r', encoding='utf-8') as f:
        data = json.load(f)
    for lvl, feats in data.get('features_by_level', {}).items():
        for feat in feats:
            fid = feat.get('id', '')
            effects = feat.get('effects', [])
            resolver = feat.get('resolver', '')
            is_curated = bool(effects or resolver or fid in CURATED_FEATURE_EFFECTS)
            entry = (cname, int(lvl), fid, is_curated)
            all_json_features.append(entry)
            if not is_curated:
                all_quarantined_json_features.append(entry)

print(f"Total features across all JSONs: {len(all_json_features)}")
print(f"Total mechanics-backed (curated) features: {len(all_json_features) - len(all_quarantined_json_features)}")
print(f"Total quarantined features: {len(all_quarantined_json_features)}")

# Now check which quarantined features are missing in doc
# Extract all feature table rows in section 4
doc_features_found = []
section_4_text = doc_text[doc_text.find("## 4. Complete 157-Feature Taxonomy"):doc_text.find("## 5. System Verification")]

rows = re.findall(r'\|\s*`?([a-zA-Z0-9_\'\-\:\ \(\)/]+)`?\s*\|\s*(\d+)\s*\|\s*(Tier \d)\s*\|', section_4_text)
for fid_raw, lvl, tier in rows:
    fid_clean = re.sub(r'\s*\([LL]\d+\)', '', fid_raw).strip()
    doc_features_found.append((fid_clean, int(lvl), tier))

print(f"Total feature rows matched in doc Section 4 tables: {len(doc_features_found)}")

# Find exact differences
doc_fids = set(f[0] for f in doc_features_found)
json_q_fids = set(f[2] for f in all_quarantined_json_features)

missing_from_doc = [f for f in all_quarantined_json_features if f[2] not in doc_fids]
print("\nQuarantined features in JSON but missing in Doc tables:")
for m in missing_from_doc:
    print(f"  - Class: {m[0]}, Level: {m[1]}, ID: {m[2]}")

print("\nFeatures in Doc tables but not in JSON quarantined list:")
extra_in_doc = [f for f in doc_features_found if f[0] not in json_q_fids]
for e in extra_in_doc:
    print(f"  - ID: {e[0]}, Level: {e[1]}, Tier: {e[2]}")
