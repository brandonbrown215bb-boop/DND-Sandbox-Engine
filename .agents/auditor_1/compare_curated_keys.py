import re
import ast

with open('src/autoload/data_loader.gd', 'r', encoding='utf-8') as f:
    gd_text = f.read()

with open('src/generate_feature_matrix.py', 'r', encoding='utf-8') as f:
    py_text = f.read()

# Find CURATED_FEATURE_EFFECTS in data_loader.gd up to const CURATED_SPELL_ACCESS or similar
start_idx = gd_text.find("const CURATED_FEATURE_EFFECTS :=")
if start_idx == -1:
    start_idx = gd_text.find("const CURATED_FEATURE_EFFECTS =")

# find next const or function
next_const = gd_text.find("const ", start_idx + 30)
gd_block = gd_text[start_idx:next_const]

gd_keys = set(re.findall(r'"([a-zA-Z0-9_\'\-\:\ \(\)/]+)"\s*:\s*\{', gd_block))

# Extract keys from generate_feature_matrix.py CURATED_FEATURE_EFFECTS
curated_dict_match = re.search(r'CURATED_FEATURE_EFFECTS = (\{.*?\n\})', py_text, re.DOTALL)
py_keys = set(ast.literal_eval(curated_dict_match.group(1)).keys()) if curated_dict_match else set()

print(f"data_loader.gd CURATED_FEATURE_EFFECTS keys ({len(gd_keys)}):")
print(sorted(gd_keys))

print(f"\ngenerate_feature_matrix.py CURATED_FEATURE_EFFECTS keys ({len(py_keys)}):")
print(sorted(py_keys))

print(f"\nKeys in data_loader.gd but missing in generate_feature_matrix.py ({len(gd_keys - py_keys)}):")
print(sorted(gd_keys - py_keys))

print(f"\nKeys in generate_feature_matrix.py but missing in data_loader.gd ({len(py_keys - gd_keys)}):")
print(sorted(py_keys - gd_keys))
