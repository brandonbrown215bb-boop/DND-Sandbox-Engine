"""Generate the Gate 0 content/feature inventory.

Run from the repository root:

    python src/generate_feature_matrix.py

The script intentionally reports both raw records and registry IDs. The Godot
loader is ID-keyed, so duplicate IDs are observable content collisions rather
than harmless extra rows.
"""

from __future__ import annotations

import json
import re
from collections import defaultdict
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
DATA_ROOT = ROOT / "data" / "core"

CURATED_FEATURE_EFFECTS = {
    "fighter_second_wind": "heal_self",
    "fighter_action_surge": "grant_extra_action",
    "fighter_extra_attack": "extra_attack",
    "barbarian_rage": "grant_condition+stat_modifier",
    "barbarian_unarmored_defense": "unarmored_defense:10+DEX+CON with shield",
    "barbarian_reckless_attack": "reckless_attack",
    "monk_patient_defense": "grant_condition",
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

CURATED_SPELL_EFFECTS = {
    "hunters_mark": "hunters_mark",
}


def entries(category: str) -> list[dict]:
    result: list[dict] = []
    for path in sorted((DATA_ROOT / category).glob("*.json"), key=lambda p: p.name):
        value = json.loads(path.read_text(encoding="utf-8"))
        values = value if isinstance(value, list) else [value]
        for index, item in enumerate(values):
            if not isinstance(item, dict):
                continue
            item = dict(item)
            item["_matrix_source"] = f"{path.relative_to(ROOT).as_posix()}#{index + 1}"
            result.append(item)
    return result


def ids(category: str) -> tuple[list[dict], dict[str, list[str]]]:
    raw = entries(category)
    sources: defaultdict[str, list[str]] = defaultdict(list)
    for item in raw:
        identifier = str(item.get("id") or item.get("table_id") or "")
        sources[identifier].append(item["_matrix_source"])
    collisions = {key: value for key, value in sorted(sources.items()) if key and len(value) > 1}
    return raw, collisions


def class_metrics() -> tuple[int, int, int, int, int]:
    raw, _ = ids("classes")
    feature_total = 0
    empty_effects = 0
    spell_entries = 0
    max_level = 0
    for item in raw:
        for level, features in item.get("features_by_level", {}).items():
            max_level = max(max_level, int(level))
            if isinstance(features, list):
                feature_total += len(features)
                empty_effects += sum(
                    1 for feature in features
                    if isinstance(feature, dict) and not feature.get("effects")
                )
        spell_table = item.get("spells_known_by_level", {})
        spell_entries += sum(len(value) for value in spell_table.values() if isinstance(value, list))
    return len(raw), max_level, feature_total, empty_effects, spell_entries


def condition_names() -> list[str]:
    names: set[str] = set()
    for path in (ROOT / "src").rglob("*.gd"):
        text = path.read_text(encoding="utf-8")
        for match in re.finditer(r'(?:has_condition|add_condition)\("([^"]+)"', text):
            names.add(match.group(1))
    return sorted(names)


def setting_names() -> list[str]:
    text = (ROOT / "src" / "autoload" / "settings.gd").read_text(encoding="utf-8")
    return [name for name in re.findall(r"^var ([a-zA-Z0-9_]+):", text, re.MULTILINE) if not name.startswith("_")]


def scene_names() -> list[str]:
    return sorted(path.relative_to(ROOT).as_posix() for path in (ROOT / "scenes").rglob("*.tscn"))


def feature_rows() -> list[tuple[str, str, str, str, str, str, str]]:
    rows: list[tuple[str, str, str, str, str, str, str]] = []
    for class_record in sorted(entries("classes"), key=lambda value: str(value.get("id", ""))):
        class_id = str(class_record.get("id", ""))
        for level, features in sorted(class_record.get("features_by_level", {}).items(), key=lambda value: int(value[0])):
            if not isinstance(features, list):
                continue
            for feature in features:
                if not isinstance(feature, dict):
                    continue
                feature_id = str(feature.get("id", ""))
                effects = feature.get("effects", []) if isinstance(feature.get("effects", []), list) else []
                resolver = str(feature.get("resolver", ""))
                feature_type = str(feature.get("type", "passive"))
                curated_effect = CURATED_FEATURE_EFFECTS.get(feature_id, "")
                if effects or resolver:
                    status = "mechanics-backed"
                elif curated_effect:
                    status = "mechanics-backed"
                elif feature_type in {"active", "passive"}:
                    status = "quarantined"
                else:
                    status = "quarantined"
                implementation = "effects: %s; resolver: %s" % (
                    ", ".join(str(effect.get("type", "")) for effect in effects if isinstance(effect, dict)) or curated_effect or "none",
                    resolver or "none",
                )
                tests = "logic.data_loader" if status == "mechanics-backed" else "none"
                player_path = "Character.level_up -> CombatState/HUD" if status == "mechanics-backed" else "Not exposed: DataLoader quarantine"
                rows.append((class_id, str(level), feature_id, status, implementation, player_path, tests))
    return rows


def spell_rows() -> list[tuple[str, str, str, str, str, str]]:
    rows: list[tuple[str, str, str, str, str, str]] = []
    curated_ids = {
        "fire_bolt", "ray_of_frost", "light", "magic_missile", "shield", "mage_armor",
        "sleep", "bless", "cure_wounds", "thunderwave", "misty_step", "scorching_ray",
        "fireball", "counterspell", "hunters_mark",
    }
    for spell in sorted(entries("spells"), key=lambda value: str(value.get("id", ""))):
        spell_id = str(spell.get("id", ""))
        effects = spell.get("effects", []) if isinstance(spell.get("effects", []), list) else []
        executable_fields = [key for key in ("damage", "damage_per_dart", "damage_per_ray", "auto_hit", "effects") if spell.get(key)]
        required_fields = all(spell.get(key) is not None for key in ("casting_time", "range", "target"))
        is_curated_record = spell.get("_matrix_source", "").split("#", 1)[0].endswith("/core_spells.json")
        if spell_id in curated_ids and not is_curated_record:
            status = "superseded"
        elif spell_id in curated_ids and required_fields and executable_fields:
            status = "mechanics-backed"
        elif spell_id in curated_ids:
            status = "description-only"
        else:
            status = "quarantined"
        implementation = "fields: %s; effects: %s" % (
            ", ".join(executable_fields) or "none",
            ", ".join(str(effect.get("type", "")) for effect in effects if isinstance(effect, dict)) or CURATED_SPELL_EFFECTS.get(spell_id, "none"),
        )
        tests = "logic.spellcasting" if status == "mechanics-backed" else "none"
        if status == "superseded":
            player_path = "Manifest override -> curated Combat HUD -> CombatAction"
        elif status == "mechanics-backed":
            player_path = "Combat HUD -> CombatAction"
        else:
            player_path = "Not exposed: DataLoader curated class access"
        rows.append((spell_id, str(spell.get("level", "")), status, implementation, player_path, tests))
    return rows


def main() -> None:
    class_count, max_level, feature_total, empty_effects, spell_entries = class_metrics()
    stats: dict[str, tuple[int, int, int]] = {}
    for category in ("classes", "races", "items", "spells", "monsters", "events", "campaigns"):
        raw, collisions = ids(category)
        stats[category] = (len(raw), len({str(x.get("id") or x.get("table_id")) for x in raw}), len(collisions))

    spell_raw, _ = ids("spells")
    spell_damage = sum(1 for spell in spell_raw if spell.get("damage"))
    condition_list = condition_names()
    settings = setting_names()
    scenes = scene_names()

    print("# Gate 0 feature matrix")
    print()
    print("Generated by `python src/generate_feature_matrix.py` from `data/core/` and current source. The loader is ID-keyed, so raw records and unique registry IDs are both recorded.")
    print()
    print("| Surface | Loaded | Reachable | Implemented | Tested | Evidence |")
    print("|---|---:|---|---|---|---|")
    print(f"| Classes | {stats['classes'][1]} IDs | Character creation and Character lookup | Partial: {empty_effects}/{feature_total} raw records have empty `effects`; unsupported effectless features are quarantined | DataLoader, character creation, logic suite | {class_count} class files; levels 1-{max_level} |")
    print(f"| Levels | 1-{max_level} | Character.level_up and campaign milestones | Partial: {spell_entries} raw class spell-list entries; runtime curated access is applied by DataLoader | Logic suite | `features_by_level` and `spells_known_by_level` plus curated access |")
    print(f"| Features | {feature_total} raw records | Character.level_up | Partial: runtime validation exposes only curated effect/resolver records; broad feature execution remains open | Logic suite smoke only | Class JSON feature tables and loader validation |")
    print(f"| Races | {stats['races'][1]} IDs | Character creation and Character.initialize | Data-backed traits/proficiencies | DataLoader and character creation | {stats['races'][0]} raw records |")
    print(f"| Spells | {stats['spells'][1]} IDs | Combat HUD and CombatAction lookup | Partial: {spell_damage}/{len(spell_raw)} raw entries carry damage data | Fireball/magic missile combat tests | {stats['spells'][0]} raw records; {stats['spells'][2]} collision IDs |")
    print(f"| Items | {stats['items'][1]} IDs | Inventory, shop, combat rewards | Partial: generic item schema is loaded; effects are not a complete execution contract | Inventory/shop/save smoke | {stats['items'][0]} raw records; {stats['items'][2]} collision IDs |")
    print(f"| Conditions | {len(condition_list)} names observed | Character, combat, events, HUD | Runtime duration/add/remove/turn effects for observed names | Logic and event-choice scenarios | `{', '.join(condition_list)}` |")
    print(f"| Settings | {len(settings)} persisted values | Settings overlay and Settings autoload | Implemented persistence to `user://settings.cfg` | Overworld/settings scenario | `{', '.join(settings)}` |")
    print(f"| Scenes | {len(scenes)} scene files | Main menu, creation, overworld, combat, dungeon, event, shop, settings, defeat, completion | Terminal destinations are mapped; host presentation review remains open | Boot gate and viewport scenarios | Scene files under `scenes/` |")
    print()
    print("## Registry counts")
    print()
    print("| Registry | Raw records | Unique IDs | Raw collision IDs |")
    print("|---|---:|---:|---:|")
    for category in ("classes", "races", "items", "spells", "monsters", "events", "campaigns"):
        raw, unique, collisions = stats[category]
        print(f"| {category} | {raw} | {unique} | {collisions} |")
    print()
    print("## Per-record mechanics coverage")
    print()
    feature_coverage = feature_rows()
    spell_coverage = spell_rows()
    print("These rows are generated from production class and spell records. `quarantined` means the record is not exposed as a selectable mechanic; `superseded` means an imported duplicate is replaced by an approved curated record. Mechanics-backed rows include the player path and test boundary used by the current source.")
    print()
    print("## Exposure summary")
    print()
    print("| Surface | Mechanics-backed | Superseded | Quarantined | Other exposed statuses |")
    print("|---|---:|---:|---:|---:|")
    for label, rows in [("Class features", feature_coverage), ("Spells", spell_coverage)]:
        counts = defaultdict(int)
        for row in rows:
            counts[row[3] if label == "Class features" else row[2]] += 1
        print(f"| {label} | {counts['mechanics-backed']} | {counts['superseded']} | {counts['quarantined']} | {counts['description-only'] + counts['test-only']} |")
    print()
    print("### Class features")
    print()
    print("| Class | Level | Feature | Status | Resolver/effects | Player path | Test IDs |")
    print("|---|---:|---|---|---|---|---|")
    for class_id, level, feature_id, status, implementation, player_path, tests in feature_coverage:
        print(f"| `{class_id}` | {level} | `{feature_id}` | {status} | {implementation} | {player_path} | {tests} |")
    print()
    print("### Spells")
    print()
    print("| Spell | Level | Status | Resolver/effects | Player path | Test IDs |")
    print("|---|---:|---|---|---|---|")
    for spell_id, level, status, implementation, player_path, tests in spell_coverage:
        print(f"| `{spell_id}` | {level} | {status} | {implementation} | {player_path} | {tests} |")
    print()
    print("Regenerate with:")
    print()
    print("```powershell")
    print("python src/generate_feature_matrix.py")
    print("```")


if __name__ == "__main__":
    main()
