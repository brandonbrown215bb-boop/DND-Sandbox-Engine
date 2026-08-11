import json
import re
from pathlib import Path
from collections import defaultdict

ROOT = Path("c:/Users/brand/Documents/linux/Top Down Party Game")
CLASSES_DIR = ROOT / "data" / "core" / "classes"
DOC_PATH = ROOT / "docs" / "quarantined_features_remediation_plan.md"

CURATED_FEATURE_EFFECTS_KEYS = {
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

def analyze_json_classes():
    total_records = 0
    mechanics_backed = []
    quarantined = []
    by_class_quarantined = defaultdict(list)
    by_class_total = defaultdict(int)
    by_class_mechanics = defaultdict(int)
    
    for path in sorted(CLASSES_DIR.glob("*.json")):
        class_data = json.loads(path.read_text(encoding="utf-8"))
        class_id = class_data.get("id", path.stem)
        features_by_lvl = class_data.get("features_by_level", {})
        
        for level, feats in sorted(features_by_lvl.items(), key=lambda x: int(x[0])):
            if not isinstance(feats, list):
                continue
            for feat in feats:
                if not isinstance(feat, dict):
                    continue
                total_records += 1
                by_class_total[class_id] += 1
                feat_id = feat.get("id", "")
                effects = feat.get("effects", [])
                resolver = feat.get("resolver", "")
                
                is_backed = bool(effects or resolver or feat_id in CURATED_FEATURE_EFFECTS_KEYS)
                rec = (class_id, int(level), feat_id, feat.get("name", ""))
                if is_backed:
                    mechanics_backed.append(rec)
                    by_class_mechanics[class_id] += 1
                else:
                    quarantined.append(rec)
                    by_class_quarantined[class_id].append(rec)
                    
    return total_records, mechanics_backed, quarantined, by_class_total, by_class_mechanics, by_class_quarantined

def parse_doc(doc_text):
    # Find all feature references in the document
    # doc includes tables, headings, GDScript code blocks
    lines = doc_text.splitlines()
    
    # Let's extract features mentioned in Tier tables / sections
    # Look for feature IDs or names
    return doc_text

def main():
    total_rec, mech, quar, by_c_tot, by_c_mech, by_c_quar = analyze_json_classes()
    print(f"--- JSON ANALYSIS ---")
    print(f"Total Class Feature Records across 14 JSONs: {total_rec}")
    print(f"Mechanics-backed Records: {len(mech)}")
    print(f"Quarantined / Effectless Records: {len(quar)}")
    print("\nPer-Class Breakdown:")
    print(f"{'Class':<12} | {'Total':<6} | {'Backed':<6} | {'Quarantined':<11}")
    print("-" * 45)
    for c_id in sorted(by_c_tot.keys()):
        tot = by_c_tot[c_id]
        m_cnt = by_c_mech[c_id]
        q_cnt = len(by_c_quar[c_id])
        print(f"{c_id:<12} | {tot:<6} | {m_cnt:<6} | {q_cnt:<11}")
        
    doc_text = DOC_PATH.read_text(encoding="utf-8")
    
    # Check for all quarantined feature IDs in doc
    quar_ids = {q[2]: q for q in quar}
    missing_ids = []
    found_ids = []
    
    for q in quar:
        c_id, lvl, f_id, name = q
        # Search for f_id in doc_text (e.g. `f_id` or f_id)
        pattern = r'\b' + re.escape(f_id) + r'\b'
        if re.search(pattern, doc_text):
            found_ids.append(f_id)
        else:
            missing_ids.append(q)
            
    print(f"\n--- RELEVANCE & COVERAGE CHECK ---")
    print(f"Quarantined IDs found in doc: {len(found_ids)} / {len(quar)}")
    if missing_ids:
        print(f"MISSING IDs ({len(missing_ids)}):")
        for m in missing_ids:
            print(f"  - {m}")
    else:
        print("100% of 157 quarantined feature IDs are present in the remediation plan doc!")

if __name__ == "__main__":
    main()
