# SRD item weight manifest (Batch 078, S-032/S-196)

Brandon's ruling (#41): "Fill in documented weights but don't invent them; the SRD lists the bell as '—' (p.95)."

Every `weight` (lb) added in Batch 078 is listed with its SRD 5.2.1 source page. An item whose SRD entry is `—`, `Varies`, or absent keeps **no** `weight` key and reads as unknown (see [unknown measurements](unknown-measurements.md)).

| Item id | File | Weight (lb) | SRD 5.2.1 |
|---|---|---|---|
| `club` | data/core/items/weapons.json | 2 | p.91, Weapons table |
| `dagger` | data/core/items/weapons.json | 1 | p.91, Weapons table |
| `greatclub` | data/core/items/weapons.json | 10 | p.91, Weapons table |
| `handaxe` | data/core/items/weapons.json | 2 | p.91, Weapons table |
| `javelin` | data/core/items/weapons.json | 2 | p.91, Weapons table |
| `light_hammer` | data/core/items/weapons.json | 2 | p.91, Weapons table |
| `mace` | data/core/items/weapons.json | 4 | p.91, Weapons table |
| `quarterstaff` | data/core/items/weapons.json | 4 | p.91, Weapons table |
| `sickle` | data/core/items/weapons.json | 2 | p.91, Weapons table |
| `spear` | data/core/items/weapons.json | 3 | p.91, Weapons table |
| `dart` | data/core/items/weapons.json | 0.25 | p.91, Weapons table |
| `light_crossbow` | data/core/items/weapons.json | 5 | p.91, Weapons table |
| `shortbow` | data/core/items/weapons.json | 2 | p.91, Weapons table |
| `battleaxe` | data/core/items/weapons.json | 4 | p.91, Weapons table |
| `flail` | data/core/items/weapons.json | 2 | p.91, Weapons table |
| `glaive` | data/core/items/weapons.json | 6 | p.91, Weapons table |
| `greataxe` | data/core/items/weapons.json | 7 | p.91, Weapons table |
| `greatsword` | data/core/items/weapons.json | 6 | p.91, Weapons table |
| `halberd` | data/core/items/weapons.json | 6 | p.91, Weapons table |
| `lance` | data/core/items/weapons.json | 6 | p.91, Weapons table |
| `longsword` | data/core/items/weapons.json | 3 | p.91, Weapons table |
| `maul` | data/core/items/weapons.json | 10 | p.91, Weapons table |
| `morningstar` | data/core/items/weapons.json | 4 | p.91, Weapons table |
| `pike` | data/core/items/weapons.json | 18 | p.91, Weapons table |
| `rapier` | data/core/items/weapons.json | 2 | p.91, Weapons table |
| `scimitar` | data/core/items/weapons.json | 3 | p.91, Weapons table |
| `shortsword` | data/core/items/weapons.json | 2 | p.91, Weapons table |
| `trident` | data/core/items/weapons.json | 4 | p.91, Weapons table |
| `warhammer` | data/core/items/weapons.json | 5 | p.91, Weapons table |
| `war_pick` | data/core/items/weapons.json | 2 | p.91, Weapons table |
| `whip` | data/core/items/weapons.json | 3 | p.91, Weapons table |
| `blowgun` | data/core/items/weapons.json | 1 | p.91, Weapons table |
| `hand_crossbow` | data/core/items/weapons.json | 3 | p.91, Weapons table |
| `heavy_crossbow` | data/core/items/weapons.json | 18 | p.91, Weapons table |
| `longbow` | data/core/items/weapons.json | 2 | p.91, Weapons table |
| `musket` | data/core/items/weapons.json | 10 | p.91, Weapons table |
| `pistol` | data/core/items/weapons.json | 3 | p.91, Weapons table |
| `leather_armor` | data/core/items/armor.json | 10 | p.92, Armor table |
| `chain_mail` | data/core/items/armor.json | 55 | p.92, Armor table |
| `scale_mail` | data/core/items/armor.json | 45 | p.92, Armor table |
| `shield` | data/core/items/armor.json | 6 | p.92, Armor table |
| `potion_healing` | data/core/items/consumables.json | 0.5 | p.95, Adventuring Gear table |
| `torch` | data/core/items/consumables.json | 1 | p.95, Adventuring Gear table |
| `rope` | data/core/items/consumables.json | 5 | p.95, Adventuring Gear table |
| `component_pouch` | data/core/items/consumables.json | 2 | p.95, Adventuring Gear table |
| `holy_water` | data/core/items/consumables.json | 1 | p.95, Adventuring Gear table |
| `ball_bearings` | data/core/items/artificer_tools.json | 2 | p.95, Adventuring Gear table |

## Deliberately left unknown (SRD `—`)
- `bell` (p.95), `antitoxin` (p.95), `basic_poison` (p.95): Adventuring Gear lists `—`.
- `sling` (p.91): Weapons table lists `—`.
- `holy_symbol`: Adventuring Gear lists `Varies`.
- Gemstones, pearls and powders in srd_gear.json: no SRD weight.

## Not filled in this batch (PARTIAL)
- `explorers_pack`, `entertainers_pack`, `priests_pack`: SRD prints pack totals (p.95), but packs expand into their contents; a pack weight needs a no-double-count rule first.
- `spellbook`, `antidote`, `thieves_tools` and other consumables.json entries: not matched to an SRD row here (spellbook is not the Book row; Thieves' Tools is in the Tools table, not yet audited).
- Imported files (`imported_base_items.json`, `imported_magic_*.json`): ids that collide with curated weapons/armor use the curated winner (content_manifest.json). Non-colliding imported base items (e.g. breastplate, padded armor) and magic items were not audited this batch.
