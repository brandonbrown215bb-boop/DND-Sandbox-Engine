# Data Import Analysis: 5eTools JSON Format

This report investigates the format of the four newly added JSON files at the root of the project: [items.json](file:///run/media/pigeon/890dd7cb-9753-4f6b-b8e6-58c98e531754/Projects/Top Down Party Game/items.json), [loot.json](file:///run/media/pigeon/890dd7cb-9753-4f6b-b8e6-58c98e531754/Projects/Top Down Party Game/loot.json), [races.json](file:///run/media/pigeon/890dd7cb-9753-4f6b-b8e6-58c98e531754/Projects/Top Down Party Game/races.json), and [skills.json](file:///run/media/pigeon/890dd7cb-9753-4f6b-b8e6-58c98e531754/Projects/Top Down Party Game/skills.json).

---

## 1. Source Data Profiling & Schema Mapping

The source files follow the standard **5eTools schema**. This format is highly detailed, deeply nested, and uses specific shorthand codes that need translation to align with the game engine's simplified rules.

### Races (`races.json`)
- **Key differences**:
  - **Ability Bonuses**: 5eTools uses a list of ability score adjustments: `[{"dex": 2, "wis": 1}]`. The engine expects a key-value mapping of uppercase scores: `{"DEX": 2, "WIS": 1}`.
  - **Speed**: 5eTools expresses speed in feet (`"speed": {"walk": 30}`). The engine operates on hex coordinates, where `1 hex = 5 feet`. Walk speed must be divided by 5: `30 / 5 = 6 speed`.
  - **Size**: 5eTools uses initials (`"size": ["M"]`). The engine uses full-text names: `"size": "medium"`.
  - **Traits**: 5eTools lists features as entries with custom tag syntax (e.g. `{@damage 1d6}`).

| 5eTools Key | Engine Target Key | Translation Rule |
| :--- | :--- | :--- |
| `name` | `id` / `name` | Lowercase + snake_case name for ID; verbatim name for name. |
| `ability` | `ability_bonuses` | Convert `[{"str": 1}]` to `{"STR": 1}`. |
| `speed.walk` | `speed` | Divide walk speed by 5 (e.g. `30` -> `6`). |
| `size` | `size` | Map `M` -> `"medium"`, `S` -> `"small"`, etc. |

---

### Items (`items.json`)
- **Key differences**:
  - **Value**: 5eTools represents item value in copper pieces (cp) by default, or as a mixed string. The engine normalizes value to gold pieces (gp).
  - **Type codes**: 5eTools uses category shorthand (e.g. `SCF` -> Spellcasting Focus, `LA` -> Light Armor, `HA` -> Heavy Armor, `M` -> Melee Weapon, `R` -> Ranged Weapon, `G` -> Gear). These must map to the engine's standard types: `weapon`, `armor`, `shield`, `consumable`, `tool`, or `currency`.

| 5eTools Item Type | Engine Target Type |
| :--- | :--- |
| `LA` / `MA` / `HA` | `armor` |
| `S` | `shield` |
| `M` / `R` | `weapon` |
| `SCF` / `T` / `AT` | `tool` |
| `P` | `consumable` |

---

### Loot Tables (`loot.json`)
- **Key differences**:
  - **Rolls**: Loot tables specify coin values using multiplication equations: `cp: "4d6*100"`.
  - **Structure**: Tables are indexed by Challenge Rating (CR) bands (e.g., CR 0-4, CR 5-10) with roll ranges.
  - **Utility**: This dataset is highly useful for introducing randomized gold drops when winning combat encounters.

---

## 2. Draft Python Converter Script

Below is a draft translation script that processes `races.json` and parses individual, engine-compatible JSON files directly into the data folder:

```python
import os
import json

def convert_races():
    source_path = "races.json"
    dest_dir = "data/core/races"
    os.makedirs(dest_dir, exist_ok=True)

    with open(source_path, "r", encoding="utf-8") as f:
        data = json.load(f)

    for race in data.get("race", []):
        # Filter homebrew, focus on core sources (PHB, XPHB, DMG)
        if race.get("source") not in ["PHB", "XPHB", "DMG", "EEPC"]:
            continue

        race_name = race.get("name")
        race_id = race_name.lower().replace(" ", "_")

        # Map ability scores
        bonuses = {}
        ability_data = race.get("ability", [{}])
        if ability_data:
            scores = ability_data[0]
            for ability, val in scores.items():
                if ability in ["choose", "choose_score"]:
                    continue
                bonuses[ability.upper()] = val

        # Map speed
        speed_val = 6
        speed_data = race.get("speed", {})
        if isinstance(speed_data, dict):
            speed_val = int(speed_data.get("walk", 30)) // 5
        elif isinstance(speed_data, int):
            speed_val = speed_data // 5

        # Map size
        size_map = {"M": "medium", "S": "small", "L": "large"}
        size_code = race.get("size", ["M"])[0]
        size_val = size_map.get(size_code, "medium")

        # Map traits
        traits = []
        for entry in race.get("entries", []):
            if isinstance(entry, dict) and entry.get("type") == "entries":
                traits.append({
                    "id": "%s_%s" % (race_id, entry.get("name").lower().replace(" ", "_")),
                    "name": entry.get("name"),
                    "description": " ".join(entry.get("entries", [])),
                    "effects": []
                })

        engine_race = {
          "id": race_id,
          "name": race_name,
          "description": "%s race from %s." % (race_name, race.get("source")),
          "ability_bonuses": bonuses,
          "speed": speed_val,
          "size": size_val,
          "languages": ["Common"],
          "proficiencies": [],
          "traits": traits,
          "darkvision": race.get("darkvision", False)
        }

        # Save individual file
        with open(os.path.join(dest_dir, "%s.json" % race_id), "w", encoding="utf-8") as out:
            json.dump(engine_race, out, indent=2)

    print("Successfully converted races.")

if __name__ == "__main__":
    convert_races()
```

---

## 3. Lift and Development Effort Analysis

Importing this base content is a **medium-sized development lift** overall, depending on the level of functional integration:

### Level 1: Core Conversion & File Spawning (Low Lift: ~1–2 hours)
- **Tasks**: Write and run Python extraction scripts (similar to the draft above) to slice `races.json` and `items.json` into individual asset sheets under `data/core/`.
- **Result**: Core directories populated with hundreds of weapons, armor, and base races.

### Level 2: Engine Integration & Parsing (Medium Lift: ~4–6 hours)
- **Tasks**:
  - **Item Properties**: Update inventory AC and weapon attack resolution routines to handle items dynamically loaded from the new database instead of hardcoded starter weapons.
  - **Random Loot drops**: Write a Godot parser to resolve `loot.json` ranges and roll formulas (e.g. `4d6*10`) to calculate dropped gold upon victory in [combat_state.gd](file:///run/media/pigeon/890dd7cb-9753-4f6b-b8e6-58c98e531754/Projects/Top Down Party Game/src/combat/combat_state.gd).

### Level 3: Advanced Integration (High Lift: ~10–12 hours)
- **Tasks**: Implement character sheets and event logs that read `skills.json` details dynamically, and build out complete shopping UI categories with tabs filtering weapons, armor, and tools dynamically.
