import re
import json
import glob
import os
import sys

def verify():
    plan_path = "docs/quarantined_features_remediation_plan.md"
    if not os.path.exists(plan_path):
        print(f"ERROR: {plan_path} does not exist.")
        sys.exit(1)
        
    with open(plan_path, "r", encoding="utf-8") as f:
        content = f.read()

    # Load all class JSON feature IDs
    json_feature_ids = set()
    class_files = glob.glob("data/core/classes/*.json")
    for filepath in class_files:
        with open(filepath, "r", encoding="utf-8") as f:
            data = json.load(f)
            features_by_lvl = data.get("features_by_level", {})
            for lvl, feat_list in features_by_lvl.items():
                for feat in feat_list:
                    if "id" in feat:
                        json_feature_ids.add(feat["id"])

    print(f"Loaded {len(json_feature_ids)} feature IDs from {len(class_files)} class JSON files.")

    # Find all GDScript code blocks
    pattern = r"```gdscript\s*(.*?)\s*```"
    gdscript_blocks = re.findall(pattern, content, re.DOTALL)
    print(f"Found {len(gdscript_blocks)} GDScript code blocks in {plan_path}.")

    all_parsed_keys = []
    syntax_errors = []

    for idx, block in enumerate(gdscript_blocks, 1):
        block_clean = block.strip()
        
        # Check if block is a dictionary entry like "key": { ... } or multi-key entry
        # Wrap in outer braces if not already wrapped as full dict
        wrapped = "{" + block_clean + "}" if not block_clean.startswith("{") else block_clean
        
        # Replace GDScript booleans / null for JSON parser compatibility check if needed
        # In GDScript true/false/null are valid JSON booleans/nulls as well.
        try:
            parsed = json.loads(wrapped)
            for k, v in parsed.items():
                all_parsed_keys.append((k, v, idx))
                if k not in json_feature_ids:
                    print(f"[WARNING] Key '{k}' in block {idx} NOT FOUND in class JSON feature IDs!")
        except Exception as e:
            # Let's try evaluating as python dict literal or analyzing GDScript syntax specifically
            try:
                # Replace GDScript literals for Python eval (true -> True, false -> False, null -> None)
                py_clean = wrapped.replace("true", "True").replace("false", "False").replace("null", "None")
                parsed = eval(py_clean)
                for k, v in parsed.items():
                    all_parsed_keys.append((k, v, idx))
                    if k not in json_feature_ids:
                        print(f"[WARNING] Key '{k}' in block {idx} NOT FOUND in class JSON feature IDs!")
            except Exception as pe:
                syntax_errors.append((idx, block_clean, str(e), str(pe)))

    print("\n--- SYNTAX CHECK RESULTS ---")
    if syntax_errors:
        print(f"FAILED: Found {len(syntax_errors)} GDScript syntax errors!")
        for idx, block, json_err, py_err in syntax_errors:
            print(f"\nBlock #{idx}:")
            print("Content:")
            print(block)
            print(f"JSON Parse Error: {json_err}")
            print(f"Python Eval Error: {py_err}")
    else:
        print(f"PASSED: All {len(gdscript_blocks)} GDScript code blocks parsed with valid dictionary syntax!")

    print(f"\nTotal curated feature entries specified in code blocks: {len(all_parsed_keys)}")
    
    # Check for missing keys or mismatch
    missing_ids = [k for k, v, idx in all_parsed_keys if k not in json_feature_ids]
    if missing_ids:
        print(f"\n[WARNING] {len(missing_ids)} keys in proposed snippets do not match JSON feature IDs: {missing_ids}")
    else:
        print("\nAll proposed keys match valid feature IDs in data/core/classes/*.json!")

if __name__ == "__main__":
    verify()
