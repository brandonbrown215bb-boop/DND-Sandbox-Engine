import json
from pathlib import Path

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

GEN_MATRIX_CURATED = {
    "fighter_second_wind", "fighter_action_surge", "fighter_extra_attack",
    "barbarian_rage", "barbarian_unarmored_defense", "barbarian_reckless_attack",
    "monk_patient_defense", "monk_step_of_the_wind", "monk_martial_arts",
    "monk_bonus_unarmed_strike", "monk_flurry_of_blows", "paladin_divine_smite",
    "paladin_fighting_style", "ranger_fighting_style", "paladin_lay_on_hands",
    "paladin_divine_sense", "bard_bardic_inspiration", "ranger_favored_foe",
    "barbarian_extra_attack", "ranger_extra_attack", "monk_extra_attack",
    "paladin_extra_attack", "rogue_sneak_attack", "rogue_uncanny_dodge",
    "rogue_cunning_action", "wizard_arcane_recovery",
    "cleric_channel_divinity:_harness_divine_power", "warlock_pact_magic",
    "warlock_magical_cunning", "sorcerer_sorcery_points",
    "sorcerer_innate_sorcery", "sorcerer_metamagic", "artificer_tinker's_magic"
}

all_features = []
for p in sorted(CLASSES_DIR.glob("*.json")):
    data = json.loads(p.read_text(encoding="utf-8"))
    c_id = data["id"]
    for lvl, feats in sorted(data.get("features_by_level", {}).items(), key=lambda x: int(x[0])):
        for f in feats:
            f_id = f.get("id", "")
            effects = f.get("effects", [])
            resolver = f.get("resolver", "")
            in_dl = (f_id in DATA_LOADER_CURATED) or bool(effects) or bool(resolver)
            in_gm = (f_id in GEN_MATRIX_CURATED) or bool(effects) or bool(resolver)
            all_features.append({
                "class": c_id,
                "level": int(lvl),
                "id": f_id,
                "name": f.get("name", ""),
                "in_dl": in_dl,
                "in_gm": in_gm,
                "has_effects": bool(effects),
                "has_resolver": bool(resolver)
            })

print(f"Total feature records: {len(all_features)}")
print(f"Data loader mechanics backed: {sum(1 for f in all_features if f['in_dl'])}")
print(f"Data loader quarantined: {sum(1 for f in all_features if not f['in_dl'])}")
print(f"Gen matrix mechanics backed: {sum(1 for f in all_features if f['in_gm'])}")
print(f"Gen matrix quarantined: {sum(1 for f in all_features if not f['in_gm'])}")

diff = [f for f in all_features if f['in_dl'] != f['in_gm']]
print(f"\nDifferences between DataLoader and generate_feature_matrix.py:")
for f in diff:
    print(f"  {f['class']} L{f['level']}: {f['id']} (DataLoader backed: {f['in_dl']}, GenMatrix backed: {f['in_gm']})")

