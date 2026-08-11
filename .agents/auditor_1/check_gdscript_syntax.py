import re
import json

with open('docs/quarantined_features_remediation_plan.md', 'r', encoding='utf-8') as f:
    doc_text = f.read()

# Extract all gdscript blocks
gd_blocks = re.findall(r'```gdscript\s*(.*?)\s*```', doc_text, re.DOTALL)

print(f"Found {len(gd_blocks)} GDScript code blocks in document.")

valid_blocks = 0
invalid_blocks = 0

for idx, block in enumerate(gd_blocks):
    # Convert GDScript dictionary notation to JSON for syntax validation
    # Replace true/false/null if needed or parse in python
    try:
        # Wrap in {} if it's multiple key-values without outer braces
        wrapped = "{" + block.strip() + "}" if not block.strip().startswith("{") else block.strip()
        # Remove trailing commas before closing braces
        clean_json = re.sub(r',\s*([\}\]])', r'\1', wrapped)
        clean_json = clean_json.replace("true", "True").replace("false", "False").replace("null", "None")
        eval(clean_json)
        valid_blocks += 1
    except Exception as e:
        invalid_blocks += 1
        print(f"Block {idx+1} syntax error: {e}\nBlock content:\n{block[:200]}...\n")

print(f"GDScript block syntax validation: {valid_blocks} valid, {invalid_blocks} invalid.")
