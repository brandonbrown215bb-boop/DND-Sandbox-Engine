"""Generate a structural content/feature inventory, not gameplay certification.

Run from the repository root:

    python src/generate_feature_matrix.py

The script intentionally reports both raw records and registry IDs. The Godot
loader is ID-keyed, so duplicate IDs are observable content collisions rather
than harmless extra rows.
"""

from __future__ import annotations

import json
import re
from collections import Counter, defaultdict
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
DATA_ROOT = ROOT / "data" / "core"

def runtime_curation_ids(constant: str) -> dict[str, str]:
    """Inventory declarations, not execution or test evidence."""
    source = (ROOT / "src" / "autoload" / "data_loader.gd").read_text(encoding="utf-8")
    block = re.search(rf"const {re.escape(constant)} := \{{(.*?)^\}}", source, re.DOTALL | re.MULTILINE)
    if block is None:
        raise ValueError(f"Runtime curation table {constant} was not found")
    return {identifier: "runtime curation" for identifier in re.findall(r'^\t"([^"]+)":', block.group(1), re.MULTILINE)}


CURATED_FEATURE_EFFECTS = runtime_curation_ids("CURATED_FEATURE_EFFECTS")

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
    for item in raw + entries("subclasses"):
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
    for class_record in sorted(entries("classes") + entries("subclasses"), key=lambda value: str(value.get("id", ""))):
        class_id = str(class_record.get("id", ""))
        if "class_id" in class_record:
            class_id = f"{class_record['class_id']}/{class_id}"
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
                if feature.get("enabled", True) is False:
                    status = "quarantined"
                elif effects or resolver or feature.get("type") == "resource" or feature.get("executor"):
                    status = "mechanics-backed"
                elif curated_effect:
                    status = "mechanics-backed"
                elif feature_type in {"active", "passive"}:
                    status = "quarantined"
                else:
                    status = "quarantined"
                implementation = "effects: %s; resolver: %s; executor: %s" % (
                    ", ".join(str(effect.get("type", "")) for effect in effects if isinstance(effect, dict)) or curated_effect or "none",
                    resolver or "none",
                    feature.get("executor") or "none",
                )
                tests = "not inferred; see dated checkpoint" if status == "mechanics-backed" else "none"
                player_path = "Character.level_up -> CombatState/HUD" if status == "mechanics-backed" else "Not exposed: DataLoader quarantine"
                if class_id in {"artificer", "mystic"}:
                    player_path = "Reference only: excluded from character creation"
                rows.append((class_id, str(level), feature_id, status, implementation, player_path, tests))
    return rows


def spell_rows() -> list[tuple[str, str, str, str, str, str]]:
    """One ID per row, using the reconciled register rather than a second allowlist."""
    rows: list[tuple[str, str, str, str, str, str]] = []
    register = json.loads((ROOT / "docs/mechanics/spell_status.json").read_text(encoding="utf-8"))
    registered_ids = {spell["id"] for spell in register["spells"]}
    if registered_ids != {spell["id"] for spell in entries("spells")}:
        raise ValueError("Re-export runtime inventory and reconcile spell_status.json before generating the matrix.")
    for spell in register["spells"]:
        effects = ", ".join(spell["declared_effects"]) or "none declared"
        implementation = f"{spell['primary_behavior']}; effects: {effects}; {spell['known_limit']}"
        player_path = ", ".join(spell["classes"]) or "Outside core casting-class lists"
        if not spell["cast_available"]:
            player_path += "; cast refused before costs"
        tests = "recorded slice; full rules audit open" if spell["delivery_status"] == "recorded_slice" else "not certified; see spell register"
        rows.append((spell["id"], str(spell["level"]), spell["delivery_status"], implementation, player_path, tests))
    return rows


def main() -> None:
    class_count, max_level, feature_total, empty_effects, spell_entries = class_metrics()
    stats: dict[str, tuple[int, int, int]] = {}
    for category in ("classes", "subclasses", "races", "items", "spells", "monsters", "events", "campaigns"):
        raw, collisions = ids(category)
        stats[category] = (len(raw), len({str(x.get("id") or x.get("table_id")) for x in raw}), len(collisions))

    spell_raw, _ = ids("spells")
    spell_damage = sum(1 for spell in spell_raw if spell.get("damage"))
    condition_list = condition_names()
    settings = setting_names()
    scenes = scene_names()

    print("# Structural content and feature inventory")
    print()
    print("Generated by `python src/generate_feature_matrix.py` from `data/core/` and current source. This is a structural inventory; status labels and check locations are not production gameplay evidence. It does not set priorities or certify the target rules runtime. The loader is ID-keyed, so raw records and unique registry IDs are both recorded.")
    print()
    print("| Surface | Loaded | Reachable | Implemented | Existing check locations (not proof) | Evidence |")
    print("|---|---:|---|---|---|---|")
    print(f"| Classes | {stats['classes'][1]} reference IDs | 12 core creation choices; Artificer/Mystic excluded | Partial: {empty_effects}/{feature_total} raw records have empty `effects`; unsupported effectless features are quarantined | DataLoader, character creation, logic suite | {class_count} class files; levels 1-{max_level} |")
    print(f"| Subclasses | {stats['subclasses'][1]} IDs | Selected parent-linked progression | Partial: only selected subclass grants its enabled features | ClassFeatureChecks and class_building_blocks | Separate subclass JSON; saved subclass_id |")
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
    for category in ("classes", "subclasses", "races", "items", "spells", "monsters", "events", "campaigns"):
        raw, unique, collisions = stats[category]
        print(f"| {category} | {raw} | {unique} | {collisions} |")
    print()
    print("## Per-record mechanics coverage")
    print()
    feature_coverage = feature_rows()
    spell_coverage = spell_rows()
    print("Class-feature rows are structural inventory, not gameplay proof. Spell rows use the single [spell delivery register](mechanics/spell-status.md), one row per runtime ID; class membership is not casting support, and recorded slices are not full rules certification. The register states current verification limits. Artificer and Mystic remain reference-only.")
    print()
    print("## Exposure summary")
    print()
    print("| Surface | Mechanics-backed | Superseded | Quarantined | Other exposed statuses |")
    print("|---|---:|---:|---:|---:|")
    for label, rows in [("Class features", feature_coverage)]:
        counts = defaultdict(int)
        for row in rows:
            counts[row[3] if label == "Class features" else row[2]] += 1
        print(f"| {label} | {counts['mechanics-backed'] + counts['mechanics-backed (partial)']} | {counts['superseded']} | {counts['quarantined']} | {counts['description-only'] + counts['test-only']} |")
    print()
    print("| Spell delivery status | Unique IDs |")
    print("|---|---:|")
    for status, count in sorted(Counter(row[2] for row in spell_coverage).items()):
        print(f"| {status} | {count} |")
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
