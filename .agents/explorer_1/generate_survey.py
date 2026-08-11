import json
import glob
import os

CURATED_FEATURE_EFFECTS = {
    "fighter_second_wind": "heal_self",
    "fighter_action_surge": "grant_extra_action",
    "fighter_extra_attack": "extra_attack",
    "barbarian_rage": "grant_condition+stat_modifier",
    "barbarian_unarmored_defense": "unarmored_defense:10+DEX+CON with shield",
    "barbarian_reckless_attack": "reckless_attack",
    "monk_patient_defense": "grant_condition",
    "monk_unarmored_defense": "unarmored_defense",
    "monk_step_of_the_wind": "step_of_the_wind",
    "monk_martial_arts": "unarmed_attack",
    "monk_bonus_unarmed_strike": "unarmed_attack",
    "monk_flurry_of_blows": "unarmed_attack x2",
    "paladin_divine_smite": "divine_smite",
    "paladin_fighting_style": "defense_style:+1 AC while armored",
    "ranger_fighting_style": "archery:+2 ranged attack",
    "paladin_lay_on_hands": "lay_on_hands",
    "paladin_divine_sense": "divine_sense",
    "bard_bardic_inspiration": "bardic_inspiration",
    "ranger_favored_foe": "favored_foe",
    "barbarian_extra_attack": "extra_attack",
    "ranger_extra_attack": "extra_attack",
    "monk_extra_attack": "extra_attack",
    "paladin_extra_attack": "extra_attack",
    "rogue_sneak_attack": "sneak_attack",
    "rogue_uncanny_dodge": "reaction:uncanny_dodge",
    "rogue_cunning_action": "cunning_action",
    "wizard_arcane_recovery": "recover_spell_slots",
    "cleric_channel_divinity:_harness_divine_power": "recover_spell_slots",
    "warlock_pact_magic": "pact_magic",
    "warlock_magical_cunning": "pact_magic_recovery:half_max",
    "sorcerer_sorcery_points": "sorcery_points",
    "sorcerer_innate_sorcery": "innate_sorcery:+1 spell DC and spell-attack advantage",
    "sorcerer_metamagic": "metamagic",
    "artificer_tinker's_magic": "give_item:ball_bearings",
}

CLASSES = [
    "artificer", "barbarian", "bard", "cleric", "druid", "fighter",
    "monk", "mystic", "paladin", "ranger", "rogue", "sorcerer", "warlock", "wizard"
]

def main():
    repo_root = "c:/Users/brand/Documents/linux/Top Down Party Game"
    data_dir = os.path.join(repo_root, "data/core/classes")

    records_by_class = {}
    class_stats = {}

    total_records = 0
    total_curated = 0
    total_quarantined = 0

    for cname in CLASSES:
        fpath = os.path.join(data_dir, f"{cname}.json")
        with open(fpath, "r", encoding="utf-8") as f:
            cdata = json.load(f)
        
        feats_by_lvl = cdata.get("features_by_level", {})
        recs = []
        cur_cnt = 0
        quar_cnt = 0
        
        for lvl_str in sorted(feats_by_lvl.keys(), key=int):
            lvl = int(lvl_str)
            for feat in feats_by_lvl[lvl_str]:
                fid = feat.get("id", "")
                name = feat.get("name", "")
                desc = feat.get("description", "")
                ftype = feat.get("type", "passive")
                effects = feat.get("effects", [])
                resolver = feat.get("resolver", "")
                choices = feat.get("choices", [])
                uses = feat.get("uses")
                uses_per = feat.get("uses_per")
                action_cost = feat.get("action_cost")
                
                is_curated = fid in CURATED_FEATURE_EFFECTS
                status = "Mechanics-Backed" if is_curated else "Quarantined"
                
                if is_curated:
                    cur_cnt += 1
                else:
                    quar_cnt += 1
                
                rec = {
                    "id": fid,
                    "name": name,
                    "class": cname,
                    "level": lvl,
                    "description": desc,
                    "type": ftype,
                    "effects": effects,
                    "resolver": resolver,
                    "choices": choices,
                    "uses": uses,
                    "uses_per": uses_per,
                    "action_cost": action_cost,
                    "status": status,
                    "curated_mapping": CURATED_FEATURE_EFFECTS.get(fid, "")
                }
                recs.append(rec)
        
        records_by_class[cname] = recs
        class_stats[cname] = {
            "total": len(recs),
            "curated": cur_cnt,
            "quarantined": quar_cnt
        }
        
        total_records += len(recs)
        total_curated += cur_cnt
        total_quarantined += quar_cnt

    out_file = os.path.join(repo_root, ".agents/explorer_1/class_features_survey.md")

    lines = []
    lines.append("# Class Features Inventory Survey Report")
    lines.append("")
    lines.append("## Executive Summary")
    lines.append("")
    lines.append(f"- **Total Character Classes Surveyed**: {len(CLASSES)}")
    lines.append(f"- **Total Class Feature Records**: {total_records}")
    lines.append(f"- **Mechanics-Backed (Curated) Feature Records**: {total_curated}")
    lines.append(f"- **Quarantined / Effectless Feature Records**: **{total_quarantined}**")
    lines.append(f"- **157 Quarantined Target Verification**: {'VERIFIED PASSED' if total_quarantined == 157 else 'FAILED'}")
    lines.append("")
    lines.append("This survey cataloged every feature record across all 14 core class JSON files in `data/core/classes/*.json`. Raw JSON feature records do not carry direct `effects` or `resolver` keys; mechanics backing is applied at runtime via DataLoader's `CURATED_FEATURE_EFFECTS` dictionary in `src/autoload/data_loader.gd`.")
    lines.append("")
    lines.append("### Class Feature Metrics Summary")
    lines.append("")
    lines.append("| Class | Total Feature Records | Mechanics-Backed (Curated) | Quarantined / Effectless |")
    lines.append("|---|---:|---:|---:|")
    for cname in CLASSES:
        st = class_stats[cname]
        lines.append(f"| `{cname}` | {st['total']} | {st['curated']} | {st['quarantined']} |")
    lines.append(f"| **TOTAL** | **{total_records}** | **{total_curated}** | **{total_quarantined}** |")
    lines.append("")
    lines.append("---")
    lines.append("")
    lines.append("## Complete Class Feature Catalog by Class")
    lines.append("")

    for cname in CLASSES:
        recs = records_by_class[cname]
        st = class_stats[cname]
        lines.append(f"### {cname.capitalize()} ({st['total']} records: {st['curated']} mechanics-backed, {st['quarantined']} quarantined)")
        lines.append("")
        lines.append("| Level | ID | Name | Status | Type / Cost | Uses | JSON Effect Data | Description Summary |")
        lines.append("|---:|---|---|---|---|---|---|---|")
        for r in recs:
            cost_str = r['type']
            if r['action_cost']:
                cost_str += f" ({r['action_cost']})"
            uses_str = "None"
            if r['uses'] is not None or r['uses_per'] is not None:
                uses_str = f"{r.get('uses', '1')} / {r.get('uses_per', 'rest')}"
            
            effect_data = []
            if r['effects']:
                effect_data.append(f"effects: {r['effects']}")
            if r['resolver']:
                effect_data.append(f"resolver: {r['resolver']}")
            if r['choices']:
                effect_data.append(f"choices: {len(r['choices'])}")
            if r['curated_mapping']:
                effect_data.append(f"curated: {r['curated_mapping']}")
            
            eff_str = "; ".join(effect_data) if effect_data else "None (empty JSON)"
            desc_short = r['description'].replace("\n", " ").replace("|", "\\|")
            if len(desc_short) > 120:
                desc_short = desc_short[:117] + "..."
                
            lines.append(f"| {r['level']} | `{r['id']}` | {r['name']} | **{r['status']}** | {cost_str} | {uses_str} | {eff_str} | {desc_short} |")
        lines.append("")

    lines.append("---")
    lines.append("")
    lines.append("## Catalog of Mechanics-Backed (Curated) Features (36 Records)")
    lines.append("")
    lines.append("| Class | Level | Feature ID | Feature Name | Curated Effect Summary |")
    lines.append("|---|---:|---|---|---|")
    for cname in CLASSES:
        for r in records_by_class[cname]:
            if r['status'] == "Mechanics-Backed":
                lines.append(f"| `{r['class']}` | {r['level']} | `{r['id']}` | {r['name']} | `{r['curated_mapping']}` |")
    lines.append("")

    lines.append("---")
    lines.append("")
    lines.append("## Catalog of Quarantined / Effectless Features (157 Records)")
    lines.append("")
    lines.append("| # | Class | Level | Feature ID | Feature Name | Short Description |")
    lines.append("|---:|---|---:|---|---|---|")
    q_idx = 1
    for cname in CLASSES:
        for r in records_by_class[cname]:
            if r['status'] == "Quarantined":
                desc_short = r['description'].replace("\n", " ").replace("|", "\\|")
                if len(desc_short) > 100:
                    desc_short = desc_short[:97] + "..."
                lines.append(f"| {q_idx} | `{r['class']}` | {r['level']} | `{r['id']}` | {r['name']} | {desc_short} |")
                q_idx += 1
    lines.append("")

    with open(out_file, "w", encoding="utf-8") as f:
        f.write("\n".join(lines))
    print(f"Successfully generated survey report at: {out_file}")

if __name__ == "__main__":
    main()
