import json
import glob
import os
import re

class_files = sorted(glob.glob('data/core/classes/*.json'))
print(f"Found {len(class_files)} class files.")

with open('src/generate_feature_matrix.py', 'r', encoding='utf-8') as f:
    matrix_code = f.read()

# Load CURATED_FEATURE_EFFECTS dict from matrix_code or data_loader.gd
import ast
curated_dict_match = re.search(r'CURATED_FEATURE_EFFECTS = (\{.*?\n\})', matrix_code, re.DOTALL)
if curated_dict_match:
    CURATED_FEATURE_EFFECTS = ast.literal_eval(curated_dict_match.group(1))
else:
    CURATED_FEATURE_EFFECTS = {}

print(f"Loaded {len(CURATED_FEATURE_EFFECTS)} entries from CURATED_FEATURE_EFFECTS in generate_feature_matrix.py.")

total_features = 0
curated_count = 0
quarantined_count = 0

quarantined_by_class = {}
all_quarantined_ids = []

for cf in class_files:
    cname = os.path.basename(cf).replace('.json', '')
    with open(cf, 'r', encoding='utf-8') as f:
        data = json.load(f)
    
    features_by_level = data.get('features_by_level', {})
    c_tot = 0
    c_cur = 0
    c_quar = 0
    quar_list = []
    
    for lvl, feats in features_by_level.items():
        for feat in feats:
            c_tot += 1
            fid = feat.get('id', '')
            effects = feat.get('effects', [])
            resolver = feat.get('resolver', '')
            
            is_curated = bool(effects or resolver or fid in CURATED_FEATURE_EFFECTS)
            if is_curated:
                c_cur += 1
            else:
                c_quar += 1
                quar_list.append(fid)
                all_quarantined_ids.append(fid)
                
    total_features += c_tot
    curated_count += c_cur
    quarantined_count += c_quar
    quarantined_by_class[cname] = (c_tot, c_cur, c_quar, quar_list)
    print(f"{cname:12s}: Total={c_tot:2d}, Curated={c_cur:2d}, Quarantined={c_quar:2d}")

print(f"\nTOTAL: Total={total_features}, Curated={curated_count}, Quarantined={quarantined_count}")
print(f"Unique quarantined feature IDs count: {len(all_quarantined_ids)}")
