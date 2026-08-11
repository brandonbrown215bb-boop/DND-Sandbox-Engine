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

# Parse all markdown tables in section 4
# Rows start with | and have 5 columns: | Feature ID | Level | Tier | ... | ... |
sections = re.split(r'### 4\.\d+\s+', doc_text)

doc_rows_by_class = {}

for sec in sections[1:]:
    class_name_match = re.match(r'([A-Za-z]+)\s+\((\d+)\s+Quarantined Features\)', sec)
    if not class_name_match:
        continue
    cname = class_name_match.group(1).lower()
    claimed_count = int(class_name_match.group(2))
    
    # find table rows
    table_rows = []
    lines = sec.splitlines()
    in_table = False
    for line in lines:
        if '| Feature ID |' in line or '|---|' in line or '| Feature |' in line:
            in_table = True
            continue
        if in_table and line.strip().startswith('|') and not line.strip().startswith('####'):
            parts = [p.strip() for p in line.strip().split('|')[1:-1]]
            if len(parts) >= 3:
                fid_raw = parts[0].replace('`', '').strip()
                # strip (L1), (L2) suffixes if any
                fid_clean = re.sub(r'\s*\([LL]\d+\)', '', fid_raw).strip()
                lvl = parts[1]
                tier = parts[2]
                table_rows.append((fid_clean, lvl, tier, parts[3] if len(parts)>3 else ''))
        elif in_table and not line.strip().startswith('|'):
            in_table = False

    doc_rows_by_class[cname] = (claimed_count, table_rows)

# Now check against actual JSON files
class_files = sorted(glob.glob('data/core/classes/*.json'))

print(f"{'Class':12s} | {'JSON Quar':10s} | {'Doc Claim':10s} | {'Doc Table Rows':15s} | Match?")
print("-" * 65)

total_json_quar = 0
total_doc_claim = 0
total_doc_rows = 0

for cf in class_files:
    cname = os.path.basename(cf).replace('.json', '')
    with open(cf, 'r', encoding='utf-8') as f:
        data = json.load(f)
    
    json_quar_list = []
    for lvl, feats in data.get('features_by_level', {}).items():
        for feat in feats:
            fid = feat.get('id', '')
            effects = feat.get('effects', [])
            resolver = feat.get('resolver', '')
            is_curated = bool(effects or resolver or fid in CURATED_FEATURE_EFFECTS)
            if not is_curated:
                json_quar_list.append((fid, str(lvl)))
                
    json_q_count = len(json_quar_list)
    doc_claim, doc_rows = doc_rows_by_class.get(cname, (0, []))
    doc_r_count = len(doc_rows)
    
    total_json_quar += json_q_count
    total_doc_claim += doc_claim
    total_doc_rows += doc_r_count
    
    match = (json_q_count == doc_claim == doc_r_count)
    print(f"{cname:12s} | {json_q_count:10d} | {doc_claim:10d} | {doc_r_count:15d} | {str(match)}")

print("-" * 65)
print(f"{'TOTAL':12s} | {total_json_quar:10d} | {total_doc_claim:10d} | {total_doc_rows:15d} | {str(total_json_quar==total_doc_claim==total_doc_rows)}")
