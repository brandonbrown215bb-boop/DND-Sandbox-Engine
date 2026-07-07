# Modding and Campaign Design Guide

This guide describes how to customize, mod, and extend the Top Down Party Game using JSON configuration assets.

---

## 1. Directory Structure

Mods are loaded automatically from the `data/mods/` directory. Subfolders must align with the target content registry keys:

```text
data/mods/
└── my_custom_mod/
    ├── classes/      # Class definitions
    ├── races/        # Race stats and speed properties
    ├── items/        # Weapons, armor, tools, and consumables
    ├── spells/       # Spell files
    ├── monsters/     # Monster sheets and AI behaviors
    ├── events/       # Overworld/dungeon event tables
    └── campaigns/    # Hex grid maps and quest conditions
```

### Overriding Core Content
If a custom JSON entry shares an `"id"` (or `"table_id"` for events) with a core file loaded from `data/core/`, the custom mod entry will override the core asset.

---

## 2. Content Templates

### Spells (`spells/`)
```json
{
  "id": "bless",
  "name": "Bless",
  "level": 1,
  "school": "enchantment",
  "action_cost": "action",
  "range": 6,
  "concentration": true,
  "effects": [
    {"type": "add_condition", "condition": "blessed", "duration": 10}
  ],
  "description": "Bless up to three creatures. Targets add +1d4 to attack rolls and saving throws."
}
```

### Items (`items/`)
```json
{
  "id": "greatsword",
  "name": "Greatsword",
  "type": "weapon",
  "damage": "2d6",
  "damage_type": "slashing",
  "ability": "STR",
  "range": 1,
  "value": 50,
  "description": "A massive two-handed sword."
}
```

### Monsters (`monsters/`)
```json
{
  "id": "skeleton",
  "name": "Skeleton",
  "hit_points": "2d8 + 4",
  "armor_class": 13,
  "speed": 6,
  "ability_scores": {
    "STR": 10,
    "DEX": 14,
    "CON": 15,
    "INT": 6,
    "WIS": 8,
    "CHA": 5
  },
  "attacks": [
    {"name": "Shortbow", "ability": "DEX", "damage": "1d6 + 2", "range": 12, "damage_type": "piercing"}
  ],
  "ai_behavior": "defensive"
}
```

### Campaigns (`campaigns/`)
A campaign defines the starting levels, milestone triggers, the overworld hex map, and victory conditions.

```json
{
  "id": "my_campaign",
  "name": "My Custom Campaign",
  "description": "Defeat the goblin leader.",
  "win_condition": {
    "type": "goal",
    "goals": [
      {"type": "defeat_monster", "monster_id": "goblin_chief"}
    ]
  },
  "player_count": {"min": 2, "max": 4},
  "starting_level": 1,
  "max_level": 5,
  "milestones": [
    {"trigger": "clear_dungeon_1", "effects": [{"type": "level_up"}]}
  ],
  "map": {
    "type": "hex_grid",
    "tiles": [
      {"q": 0, "r": 0, "terrain": "town", "name": "Starting Outpost", "start": true},
      {"q": 1, "r": 0, "terrain": "plains"},
      {"q": 2, "r": 0, "terrain": "dungeon_entrance", "name": "Goblin Hideout", "dungeon_id": "goblin_hideout"}
    ]
  },
  "dungeons": {
    "goblin_hideout": {
      "name": "Goblin Hideout",
      "room_count": 4,
      "milestone_enter": null,
      "milestone_clear": "clear_dungeon_1",
      "monster_pool": ["goblin"],
      "boss": {"monster_id": "goblin_chief", "name": "Grog the Great", "bonus_hp": 10},
      "loot": [{"item_id": "gold_100"}],
      "event_table": "dungeon_events"
    }
  }
}
```
