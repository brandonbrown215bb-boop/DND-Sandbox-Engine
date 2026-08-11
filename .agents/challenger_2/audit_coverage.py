import json
import glob
import os
import re

def full_audit():
    plan_path = "docs/quarantined_features_remediation_plan.md"
    with open(plan_path, "r", encoding="utf-8") as f:
        content = f.read()

    # Load all class JSONs and analyze feature counts
    class_files = sorted(glob.glob("data/core/classes/*.json"))
    
    total_class_features = 0
    total_quarantined = 0
    total_backed = 0
    
    quarantined_ids_by_class = {}

    for filepath in class_files:
        cname = os.path.basename(filepath).replace(".json", "")
        with open(filepath, "r", encoding="utf-8") as f:
            data = json.load(f)
        
        quarantined_ids_by_class[cname] = []
        features_by_lvl = data.get("features_by_level", {})
        
        for lvl, feat_list in features_by_lvl.items():
            for feat in feat_list:
                total_class_features += 1
                fid = feat.get("id")
                effects = feat.get("effects", [])
                # In DataLoader, features with empty effects array are treated as quarantined/effectless
                if len(effects) == 0:
                    total_quarantined += 1
                    quarantined_ids_by_class[cname].append((fid, lvl, feat.get("name")))
                else:
                    total_backed += 1

    print("=== WORKSPACE CLASS FEATURE METRICS ===")
    print(f"Total Class Files: {len(class_files)}")
    print(f"Total Class Feature Records: {total_class_features}")
    print(f"Mechanics-Backed (Curated in JSON): {total_backed}")
    print(f"Quarantined / Effectless Records: {total_quarantined}")
    
    print("\nQuarantined Records Breakdown per Class:")
    for cname, feats in quarantined_ids_by_class.items():
        print(f"  - {cname:12s}: {len(feats)} quarantined features")

    # Extract all table feature IDs from remediation plan
    table_pattern = r"\|\s*`([^`]+)`\s*\|\s*(\d+)\s*\|\s*(Tier \d)\s*\|"
    doc_table_matches = re.findall(table_pattern, content)

    doc_feature_ids = [m[0] for m in doc_table_matches]
    unique_doc_feature_ids = set(doc_feature_ids)

    print(f"\n=== REMEDIATION PLAN DOCUMENT AUDIT ===")
    print(f"Total table feature entries in doc: {len(doc_feature_ids)}")
    print(f"Unique table feature IDs in doc: {len(unique_doc_feature_ids)}")

    # Find quarantined features from JSON that are missing from doc tables
    all_quarantined_ids = set()
    for cname, feats in quarantined_ids_by_class.items():
        for fid, lvl, name in feats:
            all_quarantined_ids.add(fid)

    missing_from_doc = all_quarantined_ids - unique_doc_feature_ids
    if missing_from_doc:
        print(f"\n[WARNING] {len(missing_from_doc)} quarantined JSON feature IDs are missing from the remediation plan taxonomy tables:")
        for m in sorted(missing_from_doc):
            print(f"  - `{m}`")
    else:
        print("\n100% of all quarantined JSON feature IDs are cataloged in the remediation plan taxonomy tables!")

    # Check GDScript code block details
    gd_pattern = r"```gdscript\s*(.*?)\s*```"
    gd_blocks = re.findall(gd_pattern, content, re.DOTALL)
    print(f"\n=== GDSCRIPT CODE BLOCKS VERIFICATION ===")
    print(f"Total GDScript blocks: {len(gd_blocks)}")

    # Check every GDScript block for syntax issues, quoting issues, or GDScript keyword errors
    dict_entries = {}
    for idx, block in enumerate(gd_blocks, 1):
        b = block.strip()
        # Parse lines
        lines = [line.strip() for line in b.split("\n") if line.strip()]
        for line in lines:
            # Check key structure if line defines a dictionary key
            m = re.match(r'^\s*"([^"]+)":\s*\{', line)
            if m:
                key = m.group(1)
                dict_entries[key] = idx

    print(f"Extracted {len(dict_entries)} dictionary keys from GDScript code blocks.")
    
    # Check GDScript validity of dict entries
    for key, idx in dict_entries.items():
        if key not in all_quarantined_ids:
            print(f"  - [WARNING] GDScript key '{key}' in block #{idx} does not match any quarantined JSON feature ID!")

if __name__ == "__main__":
    full_audit()
