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

doc_text = DOC_PATH.read_text(encoding="utf-8")

classes_to_check = ["bard", "cleric", "paladin", "ranger", "sorcerer", "warlock"]

for c_id in classes_to_check:
    path = CLASSES_DIR / f"{c_id}.json"
    data = json.loads(path.read_text(encoding="utf-8"))
    print(f"\n=================== CLASS: {c_id.upper()} ===================")
    for lvl, feats in sorted(data.get("features_by_level", {}).items(), key=lambda x: int(x[0])):
        for f in feats:
            f_id = f.get("id", "")
            f_name = f.get("name", "")
            effects = f.get("effects", [])
            resolver = f.get("resolver", "")
            is_backed = (f_id in DATA_LOADER_CURATED) or bool(effects) or bool(resolver)
            
            # Find in doc
            found_lines = []
            for line_no, line in enumerate(doc_text.splitlines(), 1):
                if ("| " in line or "`" in line) and (f_id in line or f_name in line):
                    found_lines.append((line_no, line))
            
            status = "MECHANICS-BACKED" if is_backed else "QUARANTINED"
            print(f"L{lvl} {f_id} ('{f_name}') -> {status}")
            if not is_backed:
                if found_lines:
                    for lno, ltxt in found_lines[:3]:
                        print(f"    Line {lno}: {ltxt}")
                else:
                    print("    NOT FOUND IN DOC!")

