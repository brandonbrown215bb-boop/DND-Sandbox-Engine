import re

with open('docs/quarantined_features_remediation_plan.md', 'r', encoding='utf-8') as f:
    text = f.read()

# Extract tables in section 4
tables_by_class = {}
current_class = None

# Match section headers like ### 4.1 Artificer (12 Quarantined Features)
class_headers = re.findall(r'### 4\.\d+\s+([A-Za-z]+)\s+\((\d+)\s+Quarantined Features\)', text)
print("Found class sections in plan:", class_headers)

# Now parse all table rows in Section 4
# Rows have format: | `feature_id` | level | Tier X | description | spec |
row_pattern = r'\|\s*`([^`]+)`\s*\|\s*(\d+)\s*\|\s*(Tier \d+)\s*\|'
all_table_rows = re.findall(row_pattern, text)

print(f"\nTotal table feature rows found in Section 4: {len(all_table_rows)}")

tier_counts = {'Tier 1': 0, 'Tier 2': 0, 'Tier 3': 0, 'Tier 4': 0}
for fid, lvl, tier in all_table_rows:
    tier_counts[tier] = tier_counts.get(tier, 0) + 1

print("Tier breakdown across section 4 tables:", tier_counts)

# Verify uniqueness of feature IDs in Section 4 tables
feature_ids_in_tables = [fid for fid, lvl, tier in all_table_rows]
unique_ids = set(feature_ids_in_tables)
print(f"Unique feature IDs in tables: {len(unique_ids)}")
if len(feature_ids_in_tables) != len(unique_ids):
    duplicates = [fid for fid in feature_ids_in_tables if feature_ids_in_tables.count(fid) > 1]
    print("DUPLICATE FEATURE IDs IN TABLES:", set(duplicates))

