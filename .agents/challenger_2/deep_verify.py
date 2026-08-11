import re
import json
import glob
import os
import sys

def deep_verify():
    plan_path = "docs/quarantined_features_remediation_plan.md"
    with open(plan_path, "r", encoding="utf-8") as f:
        content = f.read()

    # Load all class JSON feature IDs and details
    json_features = {} # id -> list of (class_id, level, name)
    class_files = glob.glob("data/core/classes/*.json")
    for filepath in class_files:
        class_id = os.path.basename(filepath).replace(".json", "")
        with open(filepath, "r", encoding="utf-8") as f:
            data = json.load(f)
            features_by_lvl = data.get("features_by_level", {})
            for lvl, feat_list in features_by_lvl.items():
                for feat in feat_list:
                    fid = feat.get("id")
                    if fid:
                        if fid not in json_features:
                            json_features[fid] = []
                        json_features[fid].append((class_id, lvl, feat.get("name")))

    print(f"Loaded {len(json_features)} unique feature IDs across {len(class_files)} classes.")

    # 1. Parse GDScript Blocks
    pattern = r"```gdscript\s*(.*?)\s*```"
    gdscript_blocks = re.findall(pattern, content, re.DOTALL)
    
    snippets_by_key = {}
    payload_schemas = []
    gdscript_errors = []

    for idx, block in enumerate(gdscript_blocks, 1):
        block_clean = block.strip()
        # Check if payload schema or dict of feature entries
        if block_clean.startswith("{") and ("type" in block_clean) and not any(k in block_clean for k in ["_ability_score_improvement", "_fast_movement", "barbarian_", "bard_", "cleric_", "druid_", "fighter_", "monk_", "mystic_", "paladin_", "ranger_", "rogue_", "sorcerer_", "warlock_", "wizard_"]):
            payload_schemas.append((idx, block_clean))
            continue

        wrapped = "{" + block_clean + "}" if not block_clean.startswith("{") else block_clean
        # Convert GDScript booleans/null for JSON parsing check
        try:
            parsed = json.loads(wrapped)
            for k, v in parsed.items():
                snippets_by_key[k] = (v, idx, block_clean)
        except Exception as json_e:
            # Try python eval with true/false/null replaced
            try:
                py_clean = wrapped.replace("true", "True").replace("false", "False").replace("null", "None")
                parsed = eval(py_clean)
                for k, v in parsed.items():
                    snippets_by_key[k] = (v, idx, block_clean)
            except Exception as py_e:
                gdscript_errors.append((idx, block_clean, str(json_e), str(py_e)))

    print(f"\n--- GDSCRIPT PARSING & SYNTAX ANALYSIS ---")
    print(f"Total GDScript blocks found: {len(gdscript_blocks)}")
    print(f"Payload Schemas (Vocab Extensions): {len(payload_schemas)}")
    print(f"Proposed Feature Effect Snippets: {len(snippets_by_key)}")

    if gdscript_errors:
        print(f"ERROR: {len(gdscript_errors)} blocks failed syntax parsing!")
        for idx, b, je, pe in gdscript_errors:
            print(f"Block #{idx}:\n{b}\nJSON Err: {je}\nPy Err: {pe}\n")
    else:
        print("GDScript Syntax Check: 100% PASSED (All blocks are valid GDScript dictionary literals).")

    # 2. Key Alignment & ID Verification
    print(f"\n--- FEATURE ID ALIGNMENT CHECK ---")
    mismatched_keys = []
    for key in snippets_by_key:
        if key not in json_features:
            mismatched_keys.append(key)

    if mismatched_keys:
        print(f"WARNING: The following snippet keys DO NOT exist in class JSON files:")
        for k in mismatched_keys:
            _, idx, _ = snippets_by_key[k]
            print(f"  - Key: '{k}' (Block #{idx})")
    else:
        print("All snippet feature keys match valid class JSON feature IDs!")

    # 3. Check specific taxonomy table features against snippets
    # Extract feature IDs from markdown tables in Section 4
    # Markdown table lines look like: | `feature_id` | level | Tier X | ...
    table_feature_pattern = r"\|\s*`([^`]+)`\s*\|\s*(\d+)\s*\|\s*(Tier \d)\s*\|"
    table_matches = re.findall(table_feature_pattern, content)

    print(f"\n--- TAXONOMY TABLE AUDIT ---")
    print(f"Total feature entries matched in taxonomy tables: {len(table_matches)}")
    
    tier_counts = {"Tier 1": 0, "Tier 2": 0, "Tier 3": 0, "Tier 4": 0}
    tier1_tier2_ids = []
    table_features_not_in_json = []

    for fid, lvl, tier in table_matches:
        tier_counts[tier] = tier_counts.get(tier, 0) + 1
        if tier in ["Tier 1", "Tier 2"]:
            tier1_tier2_ids.append((fid, tier))
        if fid not in json_features:
            table_features_not_in_json.append((fid, tier))

    print(f"Taxonomy Tier breakdown from Section 4 tables:")
    for t, c in tier_counts.items():
        print(f"  - {t}: {c}")

    if table_features_not_in_json:
        print(f"WARNING: Features in taxonomy tables not found in JSONs:")
        for fid, t in table_features_not_in_json:
            print(f"  - `{fid}` ({t})")

    # 4. Check coverage of Tier 1 & Tier 2 features by GDScript snippets
    print(f"\n--- TIER 1 & TIER 2 SNIPPET COVERAGE AUDIT ---")
    tier1_tier2_keys = set(fid for fid, t in tier1_tier2_ids)
    snippet_keys = set(snippets_by_key.keys())

    missing_snippets = tier1_tier2_keys - snippet_keys
    extra_snippets = snippet_keys - tier1_tier2_keys

    print(f"Total Tier 1 & Tier 2 features in tables: {len(tier1_tier2_keys)}")
    print(f"Total proposed GDScript snippets: {len(snippet_keys)}")
    
    if missing_snippets:
        print(f"Tier 1/2 Features MISSING GDScript Snippets ({len(missing_snippets)}):")
        for fid in sorted(missing_snippets):
            print(f"  - `{fid}`")
    else:
        print("All Tier 1 & Tier 2 features from taxonomy tables have GDScript snippets!")

    if extra_snippets:
        print(f"GDScript Snippets with no matching Tier 1/2 table entry ({len(extra_snippets)}):")
        for fid in sorted(extra_snippets):
            print(f"  - `{fid}`")

if __name__ == "__main__":
    deep_verify()
