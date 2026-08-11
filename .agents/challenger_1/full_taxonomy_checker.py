import json
import re
from pathlib import Path
from collections import defaultdict

ROOT = Path("c:/Users/brand/Documents/linux/Top Down Party Game")
CLASSES_DIR = ROOT / "data" / "core" / "classes"
DOC_PATH = ROOT / "docs" / "quarantined_features_remediation_plan.md"

DATA_LOADER_CURATED = {
    "fighter_second_wind", "fighter_action_surge", "fighter_extra_attack",
    "barbarian_rage", "barbarian_unarmored_defense", "barbarian_reckless_attack",
    "monk_patient_defense", "monk_unarmored_defense", "monk_step_of_the_wind",
    "monk_martial_arts", "monk_bonus_unarmed_strike", "monk_flurry_of_blows",
    "paladin_divine_smite", "paladin_fighting_style", "ranger_fighting_style",
    "paladin_lay_on_hands", "paladin_divine_sense", "bard_bardic_inspiration",
    "ranger_favored_foe", "barbarian_extra_attack", "ranger_extra_attack",
    "monk_extra_attack", "paladin_extra_attack", "rogue_sneak_attack",
    "rogue_uncanny_dodge", "rogue_cunning_action", "wizard_arcane_recovery",
    "cleric_channel_divinity:_harness_divine_power", "warlock_pact_magic",
    "warlock_magical_cunning", "sorcerer_sorcery_points",
    "sorcerer_innate_sorcery", "sorcerer_metamagic", "artificer_tinker's_magic"
}

# 1. Load all 157 quarantined features from JSON
quarantined_features = []
for p in sorted(CLASSES_DIR.glob("*.json")):
    data = json.loads(p.read_text(encoding="utf-8"))
    c_id = data["id"]
    for lvl, feats in sorted(data.get("features_by_level", {}).items(), key=lambda x: int(x[0])):
        for f in feats:
            f_id = f.get("id", "")
            effects = f.get("effects", [])
            resolver = f.get("resolver", "")
            is_backed = (f_id in DATA_LOADER_CURATED) or bool(effects) or bool(resolver)
            if not is_backed:
                quarantined_features.append({
                    "class": c_id,
                    "level": int(lvl),
                    "id": f_id,
                    "name": f.get("name", "")
                })

doc_text = DOC_PATH.read_text(encoding="utf-8")

# Let's inspect sections in doc_text:
# We can find sections or table rows in the doc.
# Let's parse all table rows in doc:
table_rows = []
for line in doc_text.splitlines():
    if line.strip().startswith("|") and not "---" in line and not "| Class |" in line and not "| Character Class |" in line:
        parts = [p.strip() for p in line.split("|")[1:-1]]
        if len(parts) >= 3:
            table_rows.append(parts)

print(f"Total Markdown Table Data Rows: {len(table_rows)}")

# Let's find for each quarantined feature record which tier it belongs to in the document
feature_tier_map = {}
feature_details_map = {}

for f in quarantined_features:
    f_id = f["id"]
    f_name = f["name"]
    c_id = f["class"]
    lvl = f["level"]
    
    # Check if f_id or f_name is in table_rows
    matched_row = None
    for row in table_rows:
        row_str = " ".join(row)
        # Check if f_id or f_name matches
        if f_id in row_str or f_name in row_str:
            matched_row = row
            break
            
    if matched_row:
        # Determine tier from row or document context
        row_str = " ".join(matched_row)
        tier_match = re.search(r'Tier\s*([1-4])', row_str, re.IGNORECASE)
        if tier_match:
            tier = int(tier_match.group(1))
        else:
            # Check context in doc where this table is located
            tier = None
        feature_tier_map[f_id] = (tier, matched_row)
    else:
        feature_tier_map[f_id] = (None, None)

print("\n--- TIER MATCHING RESULTS FOR ALL 157 FEATURES ---")
tier_counts = defaultdict(int)
class_tier_counts = defaultdict(lambda: defaultdict(int))
unmapped = []

for f in quarantined_features:
    f_id = f["id"]
    tier, row = feature_tier_map[f_id]
    if tier is not None:
        tier_counts[tier] += 1
        class_tier_counts[f["class"]][tier] += 1
    else:
        unmapped.append(f)

print("Tier Counts extracted from Doc:")
for t in sorted(tier_counts.keys()):
    print(f"  Tier {t}: {tier_counts[t]}")

print(f"Unmapped Features: {len(unmapped)}")
if unmapped:
    print("\nUnmapped Features detail:")
    for u in unmapped:
        print(f"  {u['class']} L{u['level']}: id='{u['id']}' name='{u['name']}'")

