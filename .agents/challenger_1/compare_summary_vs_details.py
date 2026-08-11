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

# Let's map each feature to its exact tier in the document tables
feature_tier = {}

for f in quarantined_features:
    f_id = f["id"]
    f_name = f["name"]
    c_id = f["class"]
    lvl = f["level"]
    
    # We look for lines containing f_id or f_name in doc
    matched_tier = None
    for line in doc_text.splitlines():
        if "| " in line and (f_id in line or f_name in line):
            # Check tier in line
            m = re.search(r'Tier\s*([1-4])', line, re.IGNORECASE)
            if m:
                matched_tier = int(m.group(1))
                break
    
    feature_tier[f_id] = (matched_tier, c_id, lvl, f_name)

# Per-class tier counts from actual detailed tables
actual_class_tier = defaultdict(lambda: defaultdict(int))
for f_id, (tier, c_id, lvl, f_name) in feature_tier.items():
    if tier is not None:
        actual_class_tier[c_id][tier] += 1
    else:
        print(f"UNMAPPED: {c_id} {f_id} {f_name}")

# Summary table from section 1.1:
# | Character Class   | Tier 1: Immediate | Tier 2: Vocab Ext | Tier 3: Subsystem | Tier 4: Ribbon | Total |
summary_table_data = {
    "artificer": (1, 0, 8, 3),
    "barbarian": (2, 2, 2, 1),
    "bard": (5, 1, 3, 3),
    "cleric": (5, 2, 7, 1),
    "druid": (4, 0, 7, 2),
    "fighter": (3, 2, 2, 1),
    "monk": (7, 5, 4, 1),
    "mystic": (1, 1, 6, 1),
    "paladin": (4, 1, 6, 1),
    "ranger": (2, 1, 5, 6),
    "rogue": (3, 4, 2, 2),
    "sorcerer": (3, 1, 6, 1),
    "warlock": (1, 0, 6, 1),
    "wizard": (1, 0, 3, 4)
}

print("\n--- COMPARISON: SUMMARY TABLE vs DETAILED FEATURE TABLES ---")
print(f"{'Class':<10} | {'Sum T1':<6} {'Act T1':<6} | {'Sum T2':<6} {'Act T2':<6} | {'Sum T3':<6} {'Act T3':<6} | {'Sum T4':<6} {'Act T4':<6} | {'Match?':<6}")
print("-" * 80)

for c_id in sorted(summary_table_data.keys()):
    st1, st2, st3, st4 = summary_table_data[c_id]
    at1 = actual_class_tier[c_id][1]
    at2 = actual_class_tier[c_id][2]
    at3 = actual_class_tier[c_id][3]
    at4 = actual_class_tier[c_id][4]
    
    match = (st1 == at1 and st2 == at2 and st3 == at3 and st4 == at4)
    print(f"{c_id:<10} | {st1:<6} {at1:<6} | {st2:<6} {at2:<6} | {st3:<6} {at3:<6} | {st4:<6} {at4:<6} | {str(match):<6}")
    if not match:
        print(f"  -> Discrepancy details for {c_id}:")
        print(f"     Summary: T1={st1}, T2={st2}, T3={st3}, T4={st4}")
        print(f"     Actual:  T1={at1}, T2={at2}, T3={at3}, T4={at4}")

