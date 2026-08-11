import json
import glob
import os
import re

with open('docs/quarantined_features_remediation_plan.md', 'r', encoding='utf-8') as f:
    doc_text = f.read()

# Extract all feature IDs mentioned in tables in Section 4 of the doc
# Table format: | `feature_id` | level | Tier ...
doc_feature_ids = set(re.findall(r'\|\s*`([^`]+)`\s*\|\s*\d+\s*\|\s*Tier', doc_text))
print(f"Total unique feature IDs found in doc tables: {len(doc_feature_ids)}")

with open('src/generate_feature_matrix.py', 'r', encoding='utf-8') as f:
    matrix_code = f.read()

import ast
curated_dict_match = re.search(r'CURATED_FEATURE_EFFECTS = (\{.*?\n\})', matrix_code, re.DOTALL)
CURATED_FEATURE_EFFECTS = ast.literal_eval(curated_dict_match.group(1)) if curated_dict_match else {}

class_files = sorted(glob.glob('data/core/classes/*.json'))

json_quarantined = set()
json_quarantined_by_class = {}

for cf in class_files:
    cname = os.path.basename(cf).replace('.json', '')
    with open(cf, 'r', encoding='utf-8') as f:
        data = json.load(f)
    
    q_list = []
    for lvl, feats in data.get('features_by_level', {}).items():
        for feat in feats:
            fid = feat.get('id', '')
            effects = feat.get('effects', [])
            resolver = feat.get('resolver', '')
            is_curated = bool(effects or resolver or fid in CURATED_FEATURE_EFFECTS)
            if not is_curated:
                json_quarantined.add(fid)
                q_list.append(fid)
    json_quarantined_by_class[cname] = q_list

print(f"Total unique quarantined feature IDs in JSON files: {len(json_quarantined)}")

missing_in_doc = json_quarantined - doc_feature_ids
extra_in_doc = doc_feature_ids - json_quarantined

print(f"\nMissing in doc ({len(missing_in_doc)}): {missing_in_doc}")
print(f"Extra in doc ({len(extra_in_doc)}): {extra_in_doc}")

# Also check monk specifically
print("\n--- Monk Analysis ---")
print("JSON quarantined monk features:", json_quarantined_by_class.get('monk'))
doc_monk_ids = set(re.findall(r'\|\s*`(monk_[^`]+)`\s*\|\s*\d+\s*\|\s*Tier', doc_text))
print("Doc monk feature IDs:", doc_monk_ids)
print("Monk missing in doc:", set(json_quarantined_by_class.get('monk')) - doc_monk_ids)
