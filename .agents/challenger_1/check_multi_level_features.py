import json
from pathlib import Path
from collections import defaultdict

ROOT = Path("c:/Users/brand/Documents/linux/Top Down Party Game")
CLASSES_DIR = ROOT / "data" / "core" / "classes"

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

# Collect exact feature records (class, level, id, name)
records = []
class_counts = defaultdict(list)

for p in sorted(CLASSES_DIR.glob("*.json")):
    data = json.loads(p.read_text(encoding="utf-8"))
    c_id = data["id"]
    for lvl, feats in sorted(data.get("features_by_level", {}).items(), key=lambda x: int(x[0])):
        for f in feats:
            f_id = f.get("id", "")
            effects = f.get("effects", [])
            resolver = f.get("resolver", "")
            is_backed = (f_id in DATA_LOADER_CURATED) or bool(effects) or bool(resolver)
            rec = {
                "class": c_id,
                "level": int(lvl),
                "id": f_id,
                "name": f.get("name", ""),
                "is_backed": is_backed
            }
            records.append(rec)
            if not is_backed:
                class_counts[c_id].append(rec)

print(f"Total feature records in JSONs: {len(records)}")
print(f"Total quarantined records (DataLoader definition): {sum(len(v) for v in class_counts.values())}")

print("\nPer Class Quarantined Records in JSON:")
for c_id in sorted(class_counts.keys()):
    q_recs = class_counts[c_id]
    print(f"\n--- {c_id.upper()} ({len(q_recs)} quarantined records) ---")
    for r in q_recs:
        print(f"  L{r['level']}: {r['id']} ('{r['name']}')")

