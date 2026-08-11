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

# Load all 157 quarantined features from JSON
quarantined_features = []
by_class = defaultdict(list)

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
                item = {
                    "class": c_id,
                    "level": int(lvl),
                    "id": f_id,
                    "name": f.get("name", "")
                }
                quarantined_features.append(item)
                by_class[c_id].append(item)

print(f"Total Quarantined Features (DataLoader contract): {len(quarantined_features)}")

doc_text = DOC_PATH.read_text(encoding="utf-8")

# Let's inspect per-class counts of quarantined features:
print("\nActual Quarantined Feature Count Per Class (DataLoader contract):")
for c_id in sorted(by_class.keys()):
    print(f"  {c_id:<12}: {len(by_class[c_id])}")

# Let's parse tables from docs/quarantined_features_remediation_plan.md
# We want to extract every feature mentioned in Sections 4, 5, 6, 7 (or Tier 1, Tier 2, Tier 3, Tier 4 tables)
# Let's write a regex parser to find table rows with feature IDs or feature names

print("\n--- PARSING DOCUMENT TABLES / SECTIONS FOR TIERS ---")

# Let's check how tiers are structured in the doc
tier_assignments = {} # feature_id -> tier

# Match lines like: | Class | Level | Feature ID | ... | Tier ... |
# Or feature tables in the doc
table_lines = [line for line in doc_text.splitlines() if line.startswith("|")]

print(f"Found {len(table_lines)} markdown table lines.")

# Let's search for feature IDs in the doc and see where they are assigned to Tier 1, 2, 3, 4
for f in quarantined_features:
    f_id = f["id"]
    # Look for occurrence in doc and identify tier
    matches = re.findall(rf'\|[^\n]*\b{re.escape(f_id)}\b[^\n]*\|', doc_text)
    if not matches:
        # try matching by simplified or exact ID in code blocks or lists
        matches = re.findall(rf'[^\n]*\b{re.escape(f_id)}\b[^\n]*', doc_text)
    
    tier_found = None
    for m in matches:
        t_match = re.search(r'Tier\s*([1-4])', m, re.IGNORECASE)
        if t_match:
            tier_found = f"Tier {t_match.group(1)}"
            break
        # also check if section header or context indicates Tier
    
    if tier_found:
        tier_assignments[f_id] = tier_found

print(f"Directly mapped {len(tier_assignments)} / 157 features to tiers from doc lines.")
