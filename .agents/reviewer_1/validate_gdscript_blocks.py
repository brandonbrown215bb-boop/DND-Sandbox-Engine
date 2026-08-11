import re
import json

with open('docs/quarantined_features_remediation_plan.md', 'r', encoding='utf-8') as f:
    text = f.read()

# Extract all gdscript blocks
gdscript_blocks = re.findall(r'```gdscript\s*(.*?)\s*```', text, re.DOTALL)

print(f"Total gdscript code blocks found: {len(gdscript_blocks)}")

valid_blocks = 0
invalid_blocks = 0

for i, block in enumerate(gdscript_blocks, 1):
    # To parse as JSON, convert GDScript booleans / null / single quotes if needed
    # GDScript dict format in doc:
    # "key": { ... } or schema examples
    # Let's wrap in braces if not wrapped
    trimmed = block.strip()
    # Replace true -> true, false -> false, GDScript string formats
    # Convert GDScript snippet to json object for syntax checking
    # If trimmed starts with "feature_id": { ... }
    json_candidate = "{" + trimmed + "}" if not trimmed.startswith("{") else trimmed
    # Remove trailing commas
    json_candidate = re.sub(r',\s*([}\]])', r'\1', json_candidate)
    
    try:
        data = json.loads(json_candidate)
        valid_blocks += 1
    except Exception as e:
        print(f"Block #{i} failed JSON syntax parsing: {e}")
        print("Block content preview:")
        print(trimmed[:200])
        print("="*40)
        invalid_blocks += 1

print(f"\nResult: {valid_blocks} valid blocks, {invalid_blocks} invalid syntax blocks.")

