import os
import json
import re
import argparse
from collections import Counter

# Source directories are configured at runtime. The importer must work from a
# clean checkout without assuming the original developer's mount points.
REPO_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
EXTERNAL_DATA_DIR = os.environ.get("FIVE_TOOLS_DATA_DIR", "")
LOCAL_RAW_DIR = os.path.join(REPO_ROOT, "5etools raw")

# Output Directories
DEST_DATA_DIR = os.path.join(REPO_ROOT, "data", "imported")
RACES_DIR = os.path.join(DEST_DATA_DIR, "races")
CLASSES_DIR = os.path.join(DEST_DATA_DIR, "classes")
ITEMS_DIR = os.path.join(DEST_DATA_DIR, "items")
SPELLS_DIR = os.path.join(DEST_DATA_DIR, "spells")
MONSTERS_DIR = os.path.join(DEST_DATA_DIR, "monsters")

# Shared core sources
ALLOWED_SOURCES = ["PHB", "XPHB", "DMG", "XDMG", "MM", "XMM", "VGM", "MTF", "EEPC", "MPMM", "TCE"]

# Global store to communicate spell lists to classes during import
global_class_spells = {}
IMPORT_REPORT_PATH = os.path.join(DEST_DATA_DIR, "import_report.json")
IMPORT_REPORT = {}


def _reset_import_report():
    global IMPORT_REPORT
    IMPORT_REPORT = {
        "schema_version": 1,
        "status": "running",
        "coverage": {
            category: {
                "source_files": [],
                "source_records": 0,
                "exported_records": 0,
                "source_ids": [],
                "exported_ids": []
            }
            for category in ("classes", "items", "spells", "monsters")
        },
        "collisions": {
            "within_source": {},
            "within_import": {},
            "with_existing_core": {}
        },
        "errors": []
    }


def _record_error(message):
    IMPORT_REPORT.setdefault("errors", []).append(str(message))


def _stable_id(record):
    if not isinstance(record, dict):
        return ""
    identifier = record.get("id") or record.get("table_id") or record.get("name")
    if not identifier:
        return ""
    identifier = str(identifier).strip()
    if record.get("id") or record.get("table_id"):
        return identifier
    return identifier.lower().replace(" ", "_").replace("'", "").replace("-", "_")


def _record_source(category, filename, records):
    stats = IMPORT_REPORT["coverage"][category]
    stats["source_files"].append(str(filename))
    stats["source_records"] += len(records)
    stats["source_ids"].extend(identifier for identifier in (_stable_id(record) for record in records) if identifier)


def _record_exported(category, records):
    stats = IMPORT_REPORT["coverage"][category]
    stats["exported_records"] += len(records)
    stats["exported_ids"].extend(identifier for identifier in (_stable_id(record) for record in records) if identifier)


def _read_record_ids(directory):
    identifiers = []
    if not os.path.isdir(directory):
        return identifiers
    for root, dirs, files in os.walk(directory):
        dirs.sort()
        for filename in sorted(files):
            if not filename.endswith(".json"):
                continue
            path = os.path.join(root, filename)
            try:
                with open(path, "r", encoding="utf-8") as source:
                    payload = json.load(source)
            except (OSError, json.JSONDecodeError):
                continue
            records = payload if isinstance(payload, list) else [payload]
            identifiers.extend(identifier for identifier in (_stable_id(record) for record in records) if identifier)
    return identifiers


def _finalize_import_report():
    core_directories = {
        "classes": os.path.join(REPO_ROOT, "data", "core", "classes"),
        "items": os.path.join(REPO_ROOT, "data", "core", "items"),
        "spells": os.path.join(REPO_ROOT, "data", "core", "spells"),
        "monsters": os.path.join(REPO_ROOT, "data", "core", "monsters")
    }
    for category, stats in IMPORT_REPORT["coverage"].items():
        source_counts = Counter(stats.pop("source_ids"))
        exported_counts = Counter(stats.pop("exported_ids"))
        source_duplicates = {key: count for key, count in sorted(source_counts.items()) if count > 1}
        import_duplicates = {key: count for key, count in sorted(exported_counts.items()) if count > 1}
        core_ids = set(_read_record_ids(core_directories[category]))
        core_collisions = sorted(set(exported_counts).intersection(core_ids))
        stats["source_files"] = sorted(stats["source_files"])
        stats["skipped_records"] = max(0, stats["source_records"] - stats["exported_records"])
        stats["source_duplicate_ids"] = source_duplicates
        stats["import_duplicate_ids"] = import_duplicates
        stats["existing_core_collision_ids"] = core_collisions
        if source_duplicates:
            IMPORT_REPORT["collisions"]["within_source"][category] = source_duplicates
        if import_duplicates:
            IMPORT_REPORT["collisions"]["within_import"][category] = import_duplicates
        if core_collisions:
            IMPORT_REPORT["collisions"]["with_existing_core"][category] = core_collisions
    IMPORT_REPORT["status"] = "completed_with_errors" if IMPORT_REPORT["errors"] else "completed"
    os.makedirs(os.path.dirname(IMPORT_REPORT_PATH), exist_ok=True)
    with open(IMPORT_REPORT_PATH, "w", encoding="utf-8") as report_file:
        json.dump(IMPORT_REPORT, report_file, indent=2, sort_keys=True)
    return IMPORT_REPORT


def _assert_not_curated(path, label):
    curated_root = os.path.abspath(os.path.join(REPO_ROOT, "data", "core"))
    candidate = os.path.abspath(path)
    try:
        inside_curated = os.path.commonpath([candidate, curated_root]) == curated_root
    except ValueError:
        inside_curated = False
    if inside_curated:
        raise ValueError(f"{label} cannot be inside the curated data/core directory: {candidate}")


def configure_paths(external_data_dir, raw_dir=None, output_dir=None, report_path=None):
    global EXTERNAL_DATA_DIR, LOCAL_RAW_DIR, DEST_DATA_DIR
    global RACES_DIR, CLASSES_DIR, ITEMS_DIR, SPELLS_DIR, MONSTERS_DIR
    global IMPORT_REPORT_PATH
    EXTERNAL_DATA_DIR = os.path.abspath(external_data_dir)
    LOCAL_RAW_DIR = os.path.abspath(raw_dir or os.path.join(REPO_ROOT, "5etools raw"))
    DEST_DATA_DIR = os.path.abspath(output_dir or os.path.join(REPO_ROOT, "data", "imported"))
    IMPORT_REPORT_PATH = os.path.abspath(report_path or os.path.join(DEST_DATA_DIR, "import_report.json"))
    _assert_not_curated(DEST_DATA_DIR, "output directory")
    _assert_not_curated(IMPORT_REPORT_PATH, "report path")
    _reset_import_report()
    RACES_DIR = os.path.join(DEST_DATA_DIR, "races")
    CLASSES_DIR = os.path.join(DEST_DATA_DIR, "classes")
    ITEMS_DIR = os.path.join(DEST_DATA_DIR, "items")
    SPELLS_DIR = os.path.join(DEST_DATA_DIR, "spells")
    MONSTERS_DIR = os.path.join(DEST_DATA_DIR, "monsters")


def clean_text(text):
    if not text:
        return ""
    # Strip 5eTools markup
    text = re.sub(r"\{@(dice|damage|item|spell|condition|dc|variantrule|book|class|creature) ([^}]+)\}", r"\2", text)
    text = re.sub(r"\|[A-Za-z0-9-]+", "", text)
    return text.strip()


def parse_damage_formula(text):
    # Search for dice patterns: e.g. "1d6 + 2" or "8d6" or "1d4"
    match = re.search(r"(\d+d\d+(?:\s*[\+-]\s*\d+)?)", text)
    if match:
        return match.group(1).replace(" ", "")
    return None


def convert_classes():
    print("[Importer] Processing raw classes...")
    source_dir = os.path.join(LOCAL_RAW_DIR, "class")
    if not os.path.exists(source_dir):
        message = f"Class source folder '{source_dir}' not found."
        print(f"[Importer] Error: {message}")
        _record_error(message)
        return

    primary_abilities = {
        "Barbarian": "STR", "Bard": "CHA", "Cleric": "WIS", "Druid": "WIS",
        "Fighter": "STR", "Monk": "DEX", "Paladin": "STR", "Ranger": "DEX",
        "Rogue": "DEX", "Sorcerer": "CHA", "Warlock": "CHA", "Wizard": "INT",
        "Artificer": "INT", "Mystic": "INT"
    }

    saving_throws = {
        "Barbarian": ["STR", "CON"], "Bard": ["DEX", "CHA"], "Cleric": ["WIS", "CHA"],
        "Druid": ["INT", "WIS"], "Fighter": ["STR", "CON"], "Monk": ["STR", "DEX"],
        "Paladin": ["WIS", "CHA"], "Ranger": ["STR", "DEX"], "Rogue": ["DEX", "INT"],
        "Sorcerer": ["CON", "CHA"], "Warlock": ["WIS", "CHA"], "Wizard": ["INT", "WIS"],
        "Artificer": ["CON", "INT"], "Mystic": ["INT", "WIS"]
    }

    converted_count = 0

    for filename in sorted(os.listdir(source_dir)):
        if not filename.endswith(".json"):
            continue
        
        path = os.path.join(source_dir, filename)
        with open(path, "r", encoding="utf-8") as f:
            data = json.load(f)

        classes_list = data.get("class", [])
        _record_source("classes", filename, classes_list)
        if not classes_list:
            continue

        # Extract main class (prefer PHB or TCE sources)
        main_class = None
        for c in classes_list:
            if c.get("source") in ALLOWED_SOURCES:
                main_class = c
                break
        if not main_class:
            main_class = classes_list[0]

        class_name = main_class.get("name")
        class_id = class_name.lower().replace(" ", "_")

        # Map hit die
		hd = main_class.get("hd", {}).get("faces", 8)
        hit_die_str = f"d{hd}"

        # Map saving throws
        saves = saving_throws.get(class_name, ["STR", "DEX"])

        # Map starting equipment placeholders
        equipment = ["leather_armor", "shield"]
        if class_name in ["Fighter", "Paladin", "Barbarian"]:
            equipment = ["chain_mail", "shield", "longsword"]
        elif class_name in ["Wizard", "Sorcerer", "Warlock"]:
            equipment = ["leather_armor", "dagger"]

        # Parse spell slots by level (classTableGroups)
        spell_slots = {}
        # Parse standard full caster or half caster slots from groups if available
        # Defaulting simple full caster spell slots up to level 5:
        # Level 1: [2, 0, 0]
        # Level 2: [3, 0, 0]
        # Level 3: [4, 2, 0]
        # Level 4: [4, 3, 0]
        # Level 5: [4, 3, 2]
        is_caster = class_name in ["Wizard", "Cleric", "Druid", "Bard", "Sorcerer"]
        is_half_caster = class_name in ["Paladin", "Ranger", "Artificer"]
        
        if is_caster:
            spell_slots = {
                "1": [2],
                "2": [3],
                "3": [4, 2],
                "4": [4, 3],
                "5": [4, 3, 2]
            }
        elif is_half_caster:
            spell_slots = {
                "1": [0],
                "2": [2],
                "3": [3],
                "4": [3],
                "5": [4, 2]
            }

        # Retrieve spells populated from convert_spells()
        class_spells = global_class_spells.get(class_id, {})
        cantrips_known = class_spells.get(0, [])
        spells_known_by_level = {str(lvl): class_spells.get(lvl, []) for lvl in range(1, 4)}

        # Parse features by level
        features_by_level = {str(lvl): [] for lvl in range(1, 6)}
        features_list = data.get("classFeature", [])
        
        for f_data in features_list:
            lvl = f_data.get("level", 1)
            # Limit to Level 1 to 5 to fit game campaign limits
            if lvl > 5:
                continue
            
            f_name = f_data.get("name", "")
            f_desc = " ".join([clean_text(str(x)) for x in f_data.get("entries", [])])
            f_id = f"{class_id}_{f_name.lower().replace(' ', '_')}"

            # Map active vs passive based on terms in the description
            is_active = "action" in f_desc.lower() or "bonus action" in f_desc.lower()
            action_cost = "action"
            if "bonus action" in f_desc.lower():
                action_cost = "bonus_action"
            elif "reaction" in f_desc.lower():
                action_cost = "reaction"

            feat_entry = {
                "id": f_id,
                "name": f_name,
                "description": f_desc[:300] + "..." if len(f_desc) > 300 else f_desc,
                "type": "active" if is_active else "passive",
                "effects": []
            }
            if is_active:
                feat_entry["action_cost"] = action_cost
                feat_entry["uses"] = 1
                feat_entry["uses_per"] = "combat"

            # Avoid duplicates
            existing_ids = [feat["id"] for feat in features_by_level[str(lvl)]]
            if f_id not in existing_ids:
                features_by_level[str(lvl)].append(feat_entry)

        engine_class = {
            "id": class_id,
            "name": class_name,
            "description": f"{class_name} class. Source: {main_class.get('source')}.",
            "hit_die": hit_die_str,
            "primary_ability": primary_abilities.get(class_name, "STR"),
            "saving_throw_proficiencies": saves,
            "armor_proficiencies": ["light", "medium"] if is_caster else ["light", "medium", "heavy", "shields"],
            "weapon_proficiencies": ["simple"] if is_caster else ["simple", "martial"],
            "skill_choices": {
                "pick": 2,
                "from": ["Athletics", "Acrobatics", "Insight", "Perception", "History", "Arcana", "Stealth"]
            },
            "starting_equipment": equipment,
            "spell_slots_by_level": spell_slots,
            "cantrips_known": cantrips_known,
            "spells_known_by_level": spells_known_by_level,
            "features_by_level": features_by_level
        }

        os.makedirs(CLASSES_DIR, exist_ok=True)
        dest_path = os.path.join(CLASSES_DIR, f"{class_id}.json")
        with open(dest_path, "w", encoding="utf-8") as out:
            json.dump(engine_class, out, indent=2)
        _record_exported("classes", [engine_class])

        print(f"[Importer] Exported Class: {class_id} -> {dest_path}")
        converted_count += 1

    print(f"[Importer] Total classes converted: {converted_count}")


def convert_base_items():
    print("[Importer] Processing items-base.json...")
    source_path = os.path.join(EXTERNAL_DATA_DIR, "items-base.json")
    if not os.path.exists(source_path):
        message = f"{source_path} not found."
        print(f"[Importer] Error: {message}")
        _record_error(message)
        return

    with open(source_path, "r", encoding="utf-8") as f:
        data = json.load(f)

    base_items = data.get("baseitem", [])
    _record_source("items", os.path.basename(source_path), base_items)
    converted_items = []

    damage_types = {
        "P": "piercing", "S": "slashing", "B": "bludgeoning"
    }

    for item in base_items:
        # Check source
        if item.get("source") not in ALLOWED_SOURCES:
            continue

        name = item.get("name")
        item_id = name.lower().replace(" ", "_").replace("'", "").replace("-", "_")

        raw_val = item.get("value", 0)
        value_gp = int(raw_val // 100) if isinstance(raw_val, (int, float)) else 0

        type_code = item.get("type", "")
        desc = " ".join([clean_text(str(x)) for x in item.get("entries", [])]) if "entries" in item else ""

        # Weapons
        if type_code in ["M", "R"]:
            damage = item.get("dmg1", "1d4")
            raw_dmg_type = item.get("dmgType", "B")
            dmg_type_str = damage_types.get(raw_dmg_type, "bludgeoning")
            ability = "DEX" if "F" in item.get("property", []) else "STR"
            
            range_hex = 1
            if "range" in item:
                range_match = re.match(r"(\d+)", str(item["range"]))
                if range_match:
                    range_hex = max(1, int(range_match.group(1)) // 5)

            converted_items.append({
                "id": item_id,
                "name": name,
                "description": desc if desc else f"Standard D&D weapon: {name}.",
                "type": "weapon",
                "damage": damage,
                "damage_type": dmg_type_str,
                "ability": ability,
                "range": range_hex,
                "value": value_gp
            })

        # Armors
        elif type_code in ["LA", "MA", "HA"]:
            armor_type = "light"
            if type_code == "MA":
                armor_type = "medium"
            elif type_code == "HA":
                armor_type = "heavy"

            base_ac = int(item.get("ac", 10))

            converted_items.append({
                "id": item_id,
                "name": name,
                "description": desc if desc else f"Standard D&D armor: {name}.",
                "type": "armor",
                "armor_type": armor_type,
                "ac": base_ac,
                "stealth_disadvantage": bool(item.get("stealth", False)),
                "value": value_gp
            })

        # Shields
        elif type_code == "S":
            converted_items.append({
                "id": item_id,
                "name": name,
                "description": desc if desc else f"Standard D&D shield: {name}.",
                "type": "shield",
                "ac_bonus": 2,
                "value": value_gp
            })

    os.makedirs(ITEMS_DIR, exist_ok=True)
    dest_path = os.path.join(ITEMS_DIR, "imported_base_items.json")
    with open(dest_path, "w", encoding="utf-8") as out:
        json.dump(converted_items, out, indent=2)
    _record_exported("items", converted_items)

    print(f"[Importer] Exported {len(converted_items)} base items -> imported_base_items.json")


def convert_spells():
    print("[Importer] Processing spells-phb.json...")
    source_path = os.path.join(EXTERNAL_DATA_DIR, "spells", "spells-phb.json")
    if not os.path.exists(source_path):
        message = f"{source_path} not found."
        print(f"[Importer] Error: {message}")
        _record_error(message)
        return

    with open(source_path, "r", encoding="utf-8") as f:
        data = json.load(f)

    spells = data.get("spell", [])
    _record_source("spells", os.path.basename(source_path), spells)
    converted_spells = []

    school_map = {
        "A": "abjuration", "C": "conjuration", "D": "divination", "E": "enchantment",
        "I": "illusion", "N": "necrotic", "T": "transmutation", "V": "evocation"
    }

    damage_types = [
        "fire", "cold", "lightning", "acid", "thunder", "force", "radiant", "necrotic", "poison", "psychic"
    ]

    # Load spell-class mappings from sources.json
    global global_class_spells
    global_class_spells = {}
    sources_path = os.path.join(EXTERNAL_DATA_DIR, "spells", "sources.json")
    spell_classes = {}
    if os.path.exists(sources_path):
        with open(sources_path, "r", encoding="utf-8") as sf:
            sources_data = json.load(sf)
            for spell_name, meta in sources_data.items():
                classes = []
                for c_entry in meta.get("class", []):
                    classes.append(c_entry.get("name").lower().replace(" ", "_"))
                spell_classes[spell_name] = classes

    for spell in spells:
        name = spell.get("name")
        spell_id = name.lower().replace(" ", "_").replace("'", "").replace("-", "_")

        # Map to class spell lists if populated
        classes = spell_classes.get(name, [])
        for c_id in classes:
            if c_id not in global_class_spells:
                global_class_spells[c_id] = {0: [], 1: [], 2: [], 3: []}

        level = int(spell.get("level", 0))
        # Support spells up to Level 3 to align with campaign bounds
        if level > 3:
            continue

        # Add to global list for matching classes
        for c_id in classes:
            global_class_spells[c_id][level].append(spell_id)

        raw_school = spell.get("school", "V")
        school_str = school_map.get(raw_school, "evocation")

        # Map casting time
        time_data = spell.get("time", [{}])[0]
        casting_time = time_data.get("unit", "action")
        if casting_time == "bonus":
            casting_time = "bonus_action"

        # Map range to hexes
        range_hex = 1
        range_data = spell.get("range", {})
        dist_data = range_data.get("distance", {})
        dist_type = dist_data.get("type", "touch")
        if dist_type == "feet":
            range_hex = max(1, int(dist_data.get("amount", 30)) // 5)
        elif dist_type == "self":
            range_hex = 0

        # Description text
        desc = " ".join([clean_text(str(x)) for x in spell.get("entries", [])]) if "entries" in spell else ""

        # Map damage and healing formulas
        damage_val = parse_damage_formula(desc)
        dmg_type_str = "force"
        # Determine damage type from raw markers or description
        for dt in damage_types:
            if dt in desc.lower():
                dmg_type_str = dt
                break

        # Basic target type
        target_str = "single"
        if range_hex == 0:
            target_str = "self"
        if "cone" in desc.lower():
            target_str = "cone"
        elif "radius" in desc.lower() or "sphere" in desc.lower():
            target_str = "area"

        # Saving throws
        save_str = None
        for save in ["Dexterity", "Constitution", "Wisdom", "Strength", "Charisma", "Intelligence"]:
            if f"{save} saving throw" in desc or f"{save} save" in desc:
                save_str = save[:3].upper()
                break

        spell_entry = {
            "id": spell_id,
            "name": name,
            "description": desc[:300] + "..." if len(desc) > 300 else desc,
            "level": level,
            "school": school_str,
            "casting_time": casting_time,
            "range": range_hex,
            "target": target_str,
            "attack_type": "ranged_spell" if range_hex > 1 and "spell attack" in desc.lower() else "none"
        }
        
        if damage_val:
            if "regain" in desc.lower() or "heal" in desc.lower():
                spell_entry["effects"] = [{"type": "heal", "value": damage_val}]
            else:
                spell_entry["damage"] = damage_val
                spell_entry["damage_type"] = dmg_type_str
        
        if save_str:
            spell_entry["save"] = save_str
            if "half" in desc.lower():
                spell_entry["half_on_save"] = True

        if spell.get("concentration", False):
            spell_entry["concentration"] = True

        spell_entry["classes"] = classes
        converted_spells.append(spell_entry)

    os.makedirs(SPELLS_DIR, exist_ok=True)
    dest_path = os.path.join(SPELLS_DIR, "imported_spells.json")
    with open(dest_path, "w", encoding="utf-8") as out:
        json.dump(converted_spells, out, indent=2)
    _record_exported("spells", converted_spells)

    print(f"[Importer] Exported {len(converted_spells)} spells -> imported_spells.json")


def convert_bestiary():
    print("[Importer] Processing bestiary-mm.json...")
    source_path = os.path.join(EXTERNAL_DATA_DIR, "bestiary", "bestiary-mm.json")
    if not os.path.exists(source_path):
        message = f"{source_path} not found."
        print(f"[Importer] Error: {message}")
        _record_error(message)
        return

    with open(source_path, "r", encoding="utf-8") as f:
        data = json.load(f)

    monsters = data.get("monster", [])
    _record_source("monsters", os.path.basename(source_path), monsters)
    converted_monsters = []

    for monster in monsters:
        # Check source
        if monster.get("source") not in ALLOWED_SOURCES:
            continue

        name = monster.get("name")
        monster_id = name.lower().replace(" ", "_").replace("'", "").replace("-", "_")

        # Map HP formula (e.g. "2d8+4")
        hp_data = monster.get("hp", {})
        hp_formula = hp_data.get("formula", "1d8")

        # Map AC (first element in list or object)
        ac_data = monster.get("ac", [10])
        ac_val = 10
        if ac_data:
            first_ac = ac_data[0]
            if isinstance(first_ac, dict):
                ac_val = int(first_ac.get("ac", 10))
            elif isinstance(first_ac, int):
                ac_val = int(first_ac)

        # Map speed walk divided by 5
        walk_val = 30
        speed_data = monster.get("speed", {})
        if isinstance(speed_data, dict):
            walk_data = speed_data.get("walk", 30)
            if isinstance(walk_data, dict):
                walk_val = walk_data.get("number", 30)
            elif isinstance(walk_data, (int, float)):
                walk_val = walk_data
            elif isinstance(walk_data, str):
                match = re.search(r"(\d+)", walk_data)
                if match:
                    walk_val = int(match.group(1))
        elif isinstance(speed_data, (int, float)):
            walk_val = speed_data
        elif isinstance(speed_data, str):
            match = re.search(r"(\d+)", speed_data)
            if match:
                walk_val = int(match.group(1))
        
        speed_val = int(walk_val) // 5

        # Map ability scores
        ability_scores = {
            "STR": int(monster.get("str", 10)),
            "DEX": int(monster.get("dex", 10)),
            "CON": int(monster.get("con", 10)),
            "INT": int(monster.get("int", 10)),
            "WIS": int(monster.get("wis", 10)),
            "CHA": int(monster.get("cha", 10))
        }

        # Parse attacks list from actions
        attacks = []
        actions = monster.get("action", [])
        for act in actions:
            act_name = act.get("name", "")
            act_desc = " ".join([clean_text(str(x)) for x in act.get("entries", [])])
            
            # Filter weapon/spell attacks
            if "Weapon Attack" in act_desc or "Spell Attack" in act_desc:
                dmg_dice = parse_damage_formula(act_desc)
                if not dmg_dice:
                    dmg_dice = "1d6"

                # Check range
                range_hex = 1
                range_match = re.search(r"range (\d+)/(\d+) ft", act_desc)
                if range_match:
                    range_hex = int(range_match.group(1)) // 5
                elif "reach" in act_desc:
                    reach_match = re.search(r"reach (\d+) ft", act_desc)
                    if reach_match:
                        range_hex = max(1, int(reach_match.group(1)) // 5)

                # Damage type
                dmg_type = "bludgeoning"
                for dt in ["slashing", "piercing", "bludgeoning", "fire", "cold", "poison", "acid"]:
                    if dt in act_desc.lower():
                        dmg_type = dt
                        break

                attacks.append({
                    "name": act_name,
                    "ability": "DEX" if range_hex > 1 or "finesse" in act_desc.lower() else "STR",
                    "damage": dmg_dice,
                    "range": range_hex,
                    "damage_type": dmg_type
                })

        # Default fallback attack if none parsed
        if not attacks:
            attacks.append({
                "name": "Claws",
                "ability": "STR",
                "damage": "1d6",
                "range": 1,
                "damage_type": "slashing"
            })

        # AI Behavior heuristics
        ai_behavior = "aggressive"
        if any("spell" in a["name"].lower() for a in attacks) or any(a["range"] > 2 for a in attacks):
            ai_behavior = "defensive"

        converted_monsters.append({
            "id": monster_id,
            "name": name,
            "hit_points": hp_formula,
            "armor_class": ac_val,
            "speed": speed_val,
            "ability_scores": ability_scores,
            "attacks": attacks,
            "ai_behavior": ai_behavior
        })

    os.makedirs(MONSTERS_DIR, exist_ok=True)
    dest_path = os.path.join(MONSTERS_DIR, "imported_monsters.json")
    with open(dest_path, "w", encoding="utf-8") as out:
        json.dump(converted_monsters, out, indent=2)
    _record_exported("monsters", converted_monsters)

    print(f"[Importer] Exported {len(converted_monsters)} monsters -> imported_monsters.json")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Convert local 5eTools exports into project content.")
    parser.add_argument("--external-data-dir", default=EXTERNAL_DATA_DIR, help="Path to the 5eTools data directory (or FIVE_TOOLS_DATA_DIR).")
    parser.add_argument("--raw-dir", default=LOCAL_RAW_DIR, help="Path to the repository's raw 5eTools export directory.")
    parser.add_argument("--output-dir", default=DEST_DATA_DIR, help="Staging output content root; defaults to data/imported and cannot be data/core.")
    parser.add_argument("--report", default=None, help="Collision/coverage report path; defaults to <output-dir>/import_report.json.")
    args = parser.parse_args()
    if not args.external_data_dir:
        parser.error("--external-data-dir or FIVE_TOOLS_DATA_DIR is required; no machine-specific default is used")
    if not os.path.isdir(args.external_data_dir):
        parser.error("external data directory does not exist: %s" % args.external_data_dir)
    try:
        configure_paths(args.external_data_dir, args.raw_dir, args.output_dir, args.report)
    except ValueError as error:
        parser.error(str(error))
    print("[Importer] Starting bulk 5eTools conversion...")
    # spells must convert first to populate spell tables for classes
    convert_spells()
    convert_classes()
    convert_base_items()
    convert_bestiary()
    report = _finalize_import_report()
    print(f"[Importer] Report written -> {IMPORT_REPORT_PATH}")
    if report["errors"]:
        print(f"[Importer] Bulk conversion completed with {len(report['errors'])} source error(s).")
        raise SystemExit(1)
    print("[Importer] Bulk conversion completed successfully!")
