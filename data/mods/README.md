# Modding Guide — Top Down Party Game

Welcome! This game is designed from the ground up to support custom content.
All game data (classes, races, items, spells, monsters, events, and campaigns) is
defined in JSON files that the game loads at startup.

## How to Add Custom Content

1. Navigate to the `data/mods/` directory.
2. Create a subfolder structure matching `data/core/`:
   - `classes/` — Custom classes
   - `races/` — Custom races
   - `items/` — Custom items
   - `spells/` — Custom spells
   - `monsters/` — Custom monsters
   - `events/` — Custom event tables
   - `campaigns/` — Custom campaigns
3. Add your JSON files. They will be loaded automatically!

## Overriding Core Content

If your mod JSON has the same `id` as a core file, the collision must be named
in `data/content_manifest.json` with an explicit winner and replacement path.
Unlisted duplicate IDs fail content loading; enumeration order is not an
override contract. This lets approved packs rebalance existing content without
silently changing precedence.

## JSON Schemas

See `docs/json_schemas/` for the exact structure expected for each content type.
Look at the files in `data/core/` for working examples.

## Quick Example: Custom Race

Create `data/mods/races/dragonborn.json`:

```json
{
  "id": "dragonborn",
  "name": "Dragonborn",
  "description": "Proud dragon-blooded warriors with a devastating breath weapon.",
  "ability_bonuses": {"STR": 2, "CHA": 1},
  "speed": 6,
  "size": "medium",
  "languages": ["Common", "Draconic"],
  "proficiencies": [],
  "traits": [
    {
      "id": "breath_weapon",
      "name": "Breath Weapon",
      "description": "Exhale a 3-hex cone of fire. Each creature must make a DEX save (DC 8 + CON mod + proficiency) or take 2d6 fire damage.",
      "effects": [{"type": "breath_weapon", "damage": "2d6", "damage_type": "fire", "shape": "cone", "size": 3, "save": "DEX"}]
    },
    {
      "id": "damage_resistance",
      "name": "Damage Resistance",
      "description": "You have resistance to fire damage.",
      "effects": [{"type": "damage_resistance", "damage_type": "fire"}]
    }
  ],
  "darkvision": false
}
```

Launch the game, and Dragonborn will appear in the race selection screen!
