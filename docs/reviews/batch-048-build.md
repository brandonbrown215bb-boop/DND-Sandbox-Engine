# Batch 048 build: magic-item types and measurements (card Q-20261020-175109-7d43)

## Base
- Stacked on `batch-047-hud-chooser` @ 2342264 (PR #16).
- Reason: this batch must register its checks and scenario in `src/test_runner.gd`, `src/viewport_harness.gd` and `run_tests.ps1`, and PR #16 changes all three. Per the assignment, the PR base is `batch-047-hud-chooser`.

## Finish line
"Support wondrous, staff and rod without pretending they're tools. Add source-backed weights/volumes where available, and prove real items obey container limits. Unknown measurements stay unknown."

## Changes
### Loader
- The item-type whitelist gains `wondrous`, `staff` and `rod`. Any other unknown type is still refused with "Item has unsupported type".
- **`ItemTypeRules.definition_error`** (new file, src/characters/item_type_rules.gd), called from `DataLoader._validate_content`:
  - `weight` (lb.) and `volume` (cubic feet) must be non-negative finite numbers, or absent. Absent means unknown, never 0.
  - `worn_slot` is allowed only on `wondrous` items, and must be `head` or `feet`.
- `source_benefits` may now appear on staff, rod and wondrous items. A wondrous item with benefits must declare a `worn_slot`, because benefits apply only to equipped copies.

### Equipment
- Staff and rod are held in `Slot.HANDS`, like a wand. A held staff or rod occupies a hand for `available_spellcasting_hands`.
- A wondrous item equips only at its declared `worn_slot` (HEAD/FEET). Without one it is carried only.
- Attunement and `source_benefits` use the existing paths.

### Containers
- A compartment may state only the limit its source gives: `max_count` is now optional. It must still declare at least one of `max_count`, `max_weight` or `max_volume`.
- An unknown measurement is still refused by any compartment that limits on it, as before.

### Catalog data (`data/core/items/srd_gear.json`)
Weights are added only where SRD 5.2.1 prints a number:

| Source | Items |
|---|---|
| p.95, Adventuring Gear table | Backpack 5, Bedroll 7, Rations 2, Tinderbox 1, Waterskin 5 (the table's "full" weight), Costume 4, Mirror ½, Lamp 1, Blanket 3, Robe 4, Alchemist's Fire 1, Lantern Hooded 2, Lantern Bullseye 2, Healer's Kit 3, Acid 1, Climber's Kit 12, Crowbar 5, Caltrops 2, Oil 1 |
| p.96, Arcane Focuses | Crystal 1, Orb 3, Rod 2, Staff 4, Wand 1 |
| p.97, Druidic Focuses | Wooden staff 4 |
| p.94, Musical Instrument variants | bagpipes 6, drum 3, dulcimer 10, flute 1, horn 2, lute 2, lyre 2, pan flute 2, shawm 1, viol 1 |

- **Backpack container:** `{"compartments":[{"id":"main","max_weight":30}]}`. SRD 5.2.1 p.96 says "A Backpack holds up to 30 pounds within 1 cubic foot."
  - The 1 cubic foot is **not** enforced. The SRD gives no item volumes, so a volume limit would refuse every item as unmeasurable.
  - No item count is invented.
- **Left unknown:**
  - Bell, Antitoxin and Basic Poison: the table shows "—", which is not a number.
  - Gemstones, the pearl and the material-component powders: the SRD gives no weight.
  - All new fixture magic items.

### Unchanged on purpose
- **Core SRD arcane and druidic foci** (`arcane_rod`, `arcane_staff`, `wooden_staff`) keep type `tool`. They are SRD Adventuring Gear, not magic Rods or Staffs, and the loader has no gear type.
- **Core magic staffs** (staff_of_fire etc.) stay `weapon`, because they also act as Quarterstaffs. Moving them would change weapon attacks.
- **The 042 figurine fixtures** stay `tool` until their migration slice, as the card states.
- **The Remove Curse slot-4 threshold** in `fixture:b043_hex_blade` stays fixture-only and unsourced (card note 6). This batch adds no curse content.

## Mandatory checklist
- **(a) Refuse before cost.**
  - An over-limit stow (31 lb.) and an unmeasurable stow (bell) are refused before anything moves. The refusal carries no `seconds`.
  - The scenario asserts the backpack record is unchanged, the clock did not advance, and the item stays in the pack list.
  - An illegal equip (a wondrous item in an undeclared slot, a staff in the weapon slot) is refused by `can_equip`.
- **(b) Records.**
  - There is no new nested record shape. Backpack contents use the S-196 `state.contents`, which goes through `ContainerRules.saved_error`, then `InventoryCopies.record_state_error` per child, then `_fits` against the 30 lb. limit.
  - Logic checks: an overweight saved backpack is refused, and a legacy backpack save without contents still validates.
- **(c) Production callers.**
  - `ItemTypeRules.definition_error` is called from `DataLoader._validate_content`.
  - `ItemTypeRules.worn_slot` is called from `Inventory.can_equip`.
  - `HELD_TYPES` is used by `Inventory.available_spellcasting_hands`.
- **(d) Real persistence.** A real `SaveManager.save_game`/`load_game` of a loaded backpack, a held staff and worn attuned boots, with no cache clearing. After loading, the pack keeps its exact contents and accepts the caltrops once 2 lb. is removed.

## Validation (Godot runs strictly one at a time)
- **Full logic suite:** 5385 passed, 0 failed.
- **Fresh 2342264 baseline, run alone:** 5367 passed, 0 failed.
  - The difference is +18, matching the 18 `check.call` lines in batch_048_checks.gd.
- **Loader:** the catalog loads 289 items with 0 validation failures, the same as the baseline.
- **Scenarios:**

  | Scenario | ok |
  |---|---|
  | 031 | 25 |
  | 032 | 33 |
  | 033 | 70 |
  | 034 | 10 |
  | 035 | 9 |
  | 036 | 7 |
  | 037 | 11 |
  | 038 | 7 |
  | 039 | 10 |
  | 040 | 12 |
  | 041 | 10 |
  | 042 | 10 |
  | 043 | 11 |
  | 044 | 12 |
  | 045 | 16 |
  | 046 | 16 |
  | 047 | 10 |
  | 048 | 8 |
  | shared_spell_flow | 67 |

  There were 0 FAIL lines and 0 SCRIPT/Parse errors.

## Limits and follow-ups
- Volumes: no SRD item volumes exist, so no compartment in the catalog enforces volume. The backpack's 1 cubic foot is documented here but not enforced.
- Wondrous worn places are limited to head and feet. Neck, cloak, gloves and belt need slots the inventory does not have yet.
- Waterskin uses the SRD "full" weight; liquid quantity is S-197.
- Tool weights from the SRD Tools section (e.g. Alchemist's Supplies 8 lb.) are not added yet. `imported_magic_tools.json` repeats ids, so it needs its own pass.
- Other gear containers (Sack, Pouch, Chest, Basket, Bucket) are not in the catalog, so no capacities were added for them.
- **047 reviewer note (not changed here):** the HUD form/equipment chooser opens before `validate_actor`. A cast that `validate_actor` will refuse for another reason asks for a form first, then refuses. Nothing is spent; this is UX only. It is a follow-up.
