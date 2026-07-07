import os
import json
import re

# Directory targets
DATA_DIR = "data/core"
RACES_DIR = os.path.join(DATA_DIR, "races")
ITEMS_DIR = os.path.join(DATA_DIR, "items")

# Core sources we want to extract from
ALLOWED_SOURCES = ["PHB", "XPHB", "DMG", "XDMG", "EEPC", "MPMM"]


def clean_text(text):
    if not text:
        return ""
    # Strip 5eTools tags like {@dice 2d4 + 2}, {@item longsword}, {@dc 15}, {@condition poisoned}
    text = re.sub(r"\{@(dice|damage|item|spell|condition|dc|variantrule|book|class) ([^}]+)\}", r"\2", text)
    # Strip source markers from item name references: e.g. "longsword|phb" -> "longsword"
    text = re.sub(r"\|[A-Za-z0-9-]+", "", text)
    return text.strip()


def convert_races():
    print("[Importer] Processing races.json...")
    source_path = "races.json"
    if not os.path.exists(source_path):
        print(f"[Importer] Error: {source_path} not found.")
        return

    with open(source_path, "r", encoding="utf-8") as f:
        data = json.load(f)

    races = data.get("race", [])
    converted_count = 0

    # We only want to import the main player races to avoid cluttering with monster subraces
    target_races = [
        "Dwarf", "Halfling", "Dragonborn", "Gnome", 
        "Half-Elf", "Half-Orc", "Tiefling"
    ]

    for race in races:
        name = race.get("name")
        source = race.get("source")

        # Focus on target player races from core books
        if name not in target_races or source not in ALLOWED_SOURCES:
            continue

        race_id = name.lower().replace(" ", "_")
        
        # Ability bonuses mapping (e.g. [{"con": 2, "wis": 1}] -> {"CON": 2, "WIS": 1})
        bonuses = {}
        ability_list = race.get("ability", [{}])
        if ability_list and isinstance(ability_list[0], dict):
            for k, v in ability_list[0].items():
                if k.lower() in ["str", "dex", "con", "int", "wis", "cha"]:
                    bonuses[k.upper()] = int(v)

        # Speed mapping: walk speed in feet divided by 5 to get hex tiles
        speed_val = 6
        speed_data = race.get("speed", {})
        if isinstance(speed_data, dict):
            speed_val = int(speed_data.get("walk", 30)) // 5
        elif isinstance(speed_data, (int, float)):
            speed_val = int(speed_data) // 5

        # Size mapping
        size_map = {"M": "medium", "S": "small", "L": "large"}
        size_code = race.get("size", ["M"])[0]
        size_val = size_map.get(size_code, "medium")

        # Traits extraction
        traits = []
        for entry in race.get("entries", []):
            if isinstance(entry, dict) and entry.get("type") == "entries":
                trait_name = entry.get("name", "")
                trait_desc = " ".join([clean_text(str(x)) for x in entry.get("entries", [])])
                trait_id = f"{race_id}_{trait_name.lower().replace(' ', '_')}"
                
                # Check for standard passive trait effects if recognizable
                effects = []
                if "saving throws against poison" in trait_desc.lower():
                    effects.append({"type": "poison_resistance"})
                if "darkvision" in trait_name.lower() or "darkvision" in trait_desc.lower():
                    # Darkvision is mapped as a separate field
                    pass
                
                traits.append({
                    "id": trait_id,
                    "name": trait_name,
                    "description": trait_desc,
                    "effects": effects
                })

        engine_race = {
            "id": race_id,
            "name": name,
            "description": f"{name} race. Source: {source}.",
            "ability_bonuses": bonuses,
            "speed": speed_val,
            "size": size_val,
            "languages": ["Common"],
            "proficiencies": [],
            "traits": traits,
            "darkvision": bool(race.get("darkvision", False))
        }

        # Write individual race file
        os.makedirs(RACES_DIR, exist_ok=True)
        dest_path = os.path.join(RACES_DIR, f"{race_id}.json")
        with open(dest_path, "w", encoding="utf-8") as out:
            json.dump(engine_race, out, indent=2)
        
        print(f"[Importer] Exported Race: {race_id} -> {dest_path}")
        converted_count += 1

    print(f"[Importer] Total races converted: {converted_count}")


def convert_items():
    print("[Importer] Processing items.json...")
    source_path = "items.json"
    if not os.path.exists(source_path):
        print(f"[Importer] Error: {source_path} not found.")
        return

    with open(source_path, "r", encoding="utf-8") as f:
        data = json.load(f)

    items = data.get("item", [])
    
    weapons = []
    armors = []
    consumables = []
    tools = []

    # Map D&D damage type letters to engine strings
    damage_types = {
        "P": "piercing",
        "S": "slashing",
        "B": "bludgeoning",
        "F": "fire",
        "C": "cold",
        "L": "lightning",
        "A": "acid",
        "T": "thunder",
        "O": "force",
        "R": "radiant",
        "N": "necrotic",
        "Y": "poison",
        "I": "psychic"
    }

    for item in items:
        source = item.get("source")
        # Restrict to core / reliable sources to avoid junk/homebrew clutter
        if source not in ALLOWED_SOURCES:
            continue

        name = item.get("name", "")
        # Skip generic generic items like "+1 Armor" or template magic items that don't have real names
        if name.startswith("Generic") or name.startswith("Base") or not name:
            continue

        item_id = name.lower().replace(" ", "_").replace("+", "plus_").replace("'", "").replace(",", "").replace("(", "").replace(")", "")
        
        # Value mapping: 5eTools stores value in copper pieces (cp). Normalise to gp.
        raw_val = item.get("value", 0)
        value_gp = 0
        if isinstance(raw_val, (int, float)):
            value_gp = int(raw_val // 100)
        
        # Type categorization mapping
        type_code = item.get("type", "")
        if "|" in type_code:
            type_code = type_code.split("|")[0]

        desc = " ".join([clean_text(str(x)) for x in item.get("entries", [])]) if "entries" in item else ""

        # WEAPONS (types "M" = Melee, "R" = Ranged)
        if type_code in ["M", "R"]:
            damage = item.get("dmg1", "1d4")
            raw_dmg_type = item.get("dmgType", "B")
            dmg_type_str = damage_types.get(raw_dmg_type, "bludgeoning")
            
            # Weapon properties
            ability = "DEX" if "F" in item.get("property", []) else "STR" # Finesse weapon uses DEX
            range_hex = 1
            if "range" in item:
                # e.g. "20/60" -> extract base range 20ft -> 4 hexes
                range_match = re.match(r"(\d+)", str(item["range"]))
                if range_match:
                    range_hex = max(1, int(range_match.group(1)) // 5)

            weapons.append({
                "id": item_id,
                "name": name,
                "description": desc,
                "type": "weapon",
                "damage": damage,
                "damage_type": dmg_type_str,
                "ability": ability,
                "range": range_hex,
                "value": value_gp
            })

        # ARMORS (types "LA", "MA", "HA")
        elif type_code in ["LA", "MA", "HA"]:
            armor_type = "light"
            if type_code == "MA":
                armor_type = "medium"
            elif type_code == "HA":
                armor_type = "heavy"

            base_ac = int(item.get("ac", 10))
            bonus_ac = 0
            if "bonusAc" in item:
                bonus_match = re.match(r"\+?(\d+)", str(item["bonusAc"]))
                if bonus_match:
                    bonus_ac = int(bonus_match.group(1))

            armors.append({
                "id": item_id,
                "name": name,
                "description": desc,
                "type": "armor",
                "armor_type": armor_type,
                "ac": base_ac + bonus_ac,
                "stealth_disadvantage": bool(item.get("stealth", False)),
                "value": value_gp
            })

        # SHIELDS (type "S")
        elif type_code == "S":
            bonus_ac = 2
            if "bonusAc" in item:
                bonus_match = re.match(r"\+?(\d+)", str(item["bonusAc"]))
                if bonus_match:
                    bonus_ac += int(bonus_match.group(1))

            armors.append({
                "id": item_id,
                "name": name,
                "description": desc,
                "type": "shield",
                "ac_bonus": bonus_ac,
                "value": value_gp
            })

        # CONSUMABLES (type "P" = Potion)
        elif type_code == "P":
            effects = []
            
            # Map standard D&D healing potions
            lowered_name = name.lower()
            if "potion of healing" in lowered_name:
                effects.append({"type": "heal", "value": "2d4+2"})
            elif "greater healing" in lowered_name:
                effects.append({"type": "heal", "value": "4d4+4"})
            elif "superior healing" in lowered_name:
                effects.append({"type": "heal", "value": "8d4+8"})
            elif "supreme healing" in lowered_name:
                effects.append({"type": "heal", "value": "10d4+20"})
            elif "poison" in lowered_name:
                effects.append({"type": "apply_condition", "condition": "poisoned", "duration": 10})

            consumables.append({
                "id": item_id,
                "name": name,
                "description": desc,
                "type": "consumable",
                "action_cost": "action",
                "effects": effects,
                "value": value_gp
            })

        # TOOLS (types "SCF" = Spell focus, "T" = Tool, "AT" = Artisan Tool)
        elif type_code in ["SCF", "T", "AT"]:
            tools.append({
                "id": item_id,
                "name": name,
                "description": desc,
                "type": "tool",
                "effects": [],
                "value": value_gp
            })

    # Save grouped items as single files to avoid thousands of tiny files
    os.makedirs(ITEMS_DIR, exist_ok=True)

    with open(os.path.join(ITEMS_DIR, "imported_magic_weapons.json"), "w", encoding="utf-8") as out:
        json.dump(weapons, out, indent=2)
    print(f"[Importer] Exported {len(weapons)} magic weapons -> imported_magic_weapons.json")

    with open(os.path.join(ITEMS_DIR, "imported_magic_armor.json"), "w", encoding="utf-8") as out:
        json.dump(armors, out, indent=2)
    print(f"[Importer] Exported {len(armors)} magic armors/shields -> imported_magic_armor.json")

    with open(os.path.join(ITEMS_DIR, "imported_magic_consumables.json"), "w", encoding="utf-8") as out:
        json.dump(consumables, out, indent=2)
    print(f"[Importer] Exported {len(consumables)} magic consumables -> imported_magic_consumables.json")

    with open(os.path.join(ITEMS_DIR, "imported_magic_tools.json"), "w", encoding="utf-8") as out:
        json.dump(tools, out, indent=2)
    print(f"[Importer] Exported {len(tools)} magic tools/focuses -> imported_magic_tools.json")


if __name__ == "__main__":
    print("[Importer] Starting conversion pipeline...")
    convert_races()
    convert_items()
    print("[Importer] Conversion pipeline completed successfully!")
