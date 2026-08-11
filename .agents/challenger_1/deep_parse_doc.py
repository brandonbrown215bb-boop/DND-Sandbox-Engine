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

# Let's find for each of the 157 features where and how it is mentioned
unmatched = []
matched = {}

for f in quarantined_features:
    f_id = f["id"]
    name = f["name"]
    c_id = f["class"]
    lvl = f["level"]
    
    # Search patterns
    # 1. Exact f_id
    # 2. f_id without parens or special chars
    # 3. Exact name
    
    found = False
    for line in doc_text.splitlines():
        if f_id in line or name in line:
            found = True
            # Try to identify Tier from section or line
            break
            
    if found:
        matched[f_id] = f
    else:
        unmatched.append(f)

print(f"Total Quarantined in JSON: {len(quarantined_features)}")
print(f"Matched by ID or Name in Doc: {len(matched)}")
print(f"Unmatched in Doc: {len(unmatched)}")
if unmatched:
    print("\nUnmatched Features:")
    for u in unmatched:
        print(f"  {u['class']} L{u['level']}: id='{u['id']}' name='{u['name']}'")

