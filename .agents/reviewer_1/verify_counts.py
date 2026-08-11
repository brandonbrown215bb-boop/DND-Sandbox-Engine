import json
import glob
import os
import re

classes_dir = 'data/core/classes'
with open('src/autoload/data_loader.gd', 'r', encoding='utf-8') as f:
    dl_content = f.read()

# Extract CURATED_FEATURE_EFFECTS block
start_idx = dl_content.find('const CURATED_FEATURE_EFFECTS := {')
end_idx = dl_content.find('\n}', start_idx) + 2
curated_block = dl_content[start_idx:end_idx]

# Match keys in CURATED_FEATURE_EFFECTS
curated_keys = set(re.findall(r'"([^"]+)":\s*\{', curated_block))
print(f"Curated dict keys count in data_loader.gd: {len(curated_keys)}")
print("Curated keys:", sorted(list(curated_keys)))

class_files = glob.glob(os.path.join(classes_dir, '*.json'))
print(f"\nFound {len(class_files)} class JSON files.")

total_features = 0
total_quarantined = 0
total_curated = 0

class_stats = {}
all_quarantined_features = {}

for cf in sorted(class_files):
    cname = os.path.basename(cf).replace('.json', '')
    with open(cf, 'r', encoding='utf-8') as f:
        cdata = json.load(f)
    
    features_by_level = cdata.get('features_by_level', {})
    c_curated = 0
    c_quarantined = 0
    q_list = []
    
    for lvl, flist in features_by_level.items():
        for feat in flist:
            fid = feat.get('id')
            effects = feat.get('effects', [])
            is_curated = (fid in curated_keys) or (len(effects) > 0)
            if is_curated:
                c_curated += 1
            else:
                c_quarantined += 1
                q_list.append(fid)
            
    class_stats[cname] = {
        'total': c_curated + c_quarantined,
        'curated': c_curated,
        'quarantined': c_quarantined,
        'quarantined_ids': q_list
    }
    all_quarantined_features[cname] = q_list
    total_features += (c_curated + c_quarantined)
    total_curated += c_curated
    total_quarantined += c_quarantined

print(f"\nTOTAL FEATURES: {total_features}")
print(f"TOTAL CURATED: {total_curated}")
print(f"TOTAL QUARANTINED: {total_quarantined}\n")

print(f"{'Class':<15} | {'Total':<6} | {'Curated':<8} | {'Quarantined':<12}")
print("-" * 50)
for cname, stats in sorted(class_stats.items()):
    print(f"{cname:<15} | {stats['total']:<6} | {stats['curated']:<8} | {stats['quarantined']:<12}")

# Now let's check docs/quarantined_features_remediation_plan.md to see if all quarantined IDs are present in the document
with open('docs/quarantined_features_remediation_plan.md', 'r', encoding='utf-8') as f:
    plan_text = f.read()

missing_ids = []
found_ids = []
for cname, q_ids in sorted(all_quarantined_features.items()):
    for qid in q_ids:
        # Check if `qid` is in plan_text
        if f"`{qid}`" in plan_text:
            found_ids.append(qid)
        else:
            missing_ids.append((cname, qid))

print(f"\nQuarantined IDs found in remediation plan: {len(found_ids)} / {total_quarantined}")
if missing_ids:
    print(f"MISSING IDs ({len(missing_ids)}):")
    for cname, qid in missing_ids:
        print(f"  [{cname}] `{qid}`")
else:
    print("ALL QUARANTINED FEATURES ARE EXPLICITLY PRESENT IN REMEDIATION PLAN!")

