# Class tool items (Druid Herbalism Kit, Monk chosen tool)

Base: main `897d994`. Branch `codex/class-tool-items`. One PR, no stack.

## Source clauses (SRD 5.2.1, `/workspace/srd.txt`)
- Druid Core Traits, Tool Proficiencies: Herbalism Kit (2498). Starting
  Equipment (2500-2504): "(A) Leather Armor, Shield, Sickle, Druidic Focus
  (Quarterstaff), Explorer's Pack, Herbalism Kit, and 9 GP; or (B) 50 GP".
- Monk Starting Equipment (2972-2978): "(A) Spear, 5 Daggers, Artisan's Tools or
  Musical Instrument chosen for the tool proficiency above, Explorer's Pack,
  and 11 GP; or (B) 50 GP".

## Delivered
- `druid.json`: `herbalism_kit` added to `starting_equipment`; `starting_gold`
  9; `starting_gold_alternative` 50.
- `monk.json`: `starting_equipment_includes_tool_choice: true`;
  `starting_gold_alternative` 50.
- `ClassProgression.creation_starting_equipment(class_id, choices)`: one generic
  operation used by creation preview and `Character.initialize`; gold option
  returns no items; the declaration appends each validated chosen tool once.
- `DataLoader` refuses a non-boolean declaration or one without `tool_choices`.
- `Character.initialize` refuses a character whose class is already set
  (repeat confirmation cannot add a second item). The generic gold branch
  replaces the Bard/Cleric ID list; Barbarian keeps its own selector.
- Creation UI: `_equipment_mode()` replaces the Bard/Cleric ID lists; Druid and
  Monk now show the generic A/B selector and the gold summary.
- Item copy and proficiency stay separate; no save fields, no migration.

## Not delivered (remaining source clauses)
- Druid: Sickle, Druidic Focus (Quarterstaff), Explorer's Pack.
- Monk: Explorer's Pack (data keeps Spear and 5 Daggers).
- Rogue starting-gold alternative still absent (out of scope).

## Checks (Linux, Godot 4.7.2 headless, sequential)
- Logic suite: 6800 passed, 0 failed (473 scripts parse gate);
  `ClassToolItemChecks` adds 10, G2 checks updated to the new behaviour.
- `class_tool_items_flow` 26 ok / `class_tool_items_reload` 17 ok (fresh process).
  Covers Druid A/B with Back and cancel, two Monks (Smith's Tools, Lyre after
  Back), Random Monk, seat reset, invalid equipment refusal, repeat creation
  refusal, party and player-only save, two reload/save rounds in a fresh process.
- Old saves: `data/fixtures/tool_items/main_897d994_party.sav` was written
  by main 897d994 (`class_proficiency_creation_flow`). Its party and a
  player-only copy (party removed) load, save, reload in a fresh process and
  save again with no Flute or Herbalism Kit item added.
- Neutral renamed class (`tool_item_probe`, Monk data copy) gets its chosen
  Cook's Utensils item; without the declaration it gets proficiency only.
- Regressions passing: class_proficiency_creation_flow/reload,
  skilled_feat_creation_flow/reload, class_skill_selection_flow/_b/reload,
  bard_creation_flow, cleric_creation_flow, barbarian_choice_flow,
  character_creation.

## Explorer's Pack follow-up

Base: main 382ca63. Runtime Builder, 2026-11-03.

Source clauses (SRD 5.2.1, `/workspace/srd.txt`, matching
`reference/2024/classes/{druid,monk}.json` startingEquipment):

- Druid Starting Equipment, lines 2500-2504: "(A) Leather Armor, Shield,
  Sickle, Druidic Focus (Quarterstaff), Explorer's Pack, Herbalism Kit, and 9
  GP; or (B) 50 GP".
- Monk Starting Equipment, lines 2972-2978: "(A) Spear, 5 Daggers, Artisan's
  Tools or Musical Instrument chosen for the tool proficiency above, Explorer's
  Pack, and 11 GP; or (B) 50 GP".
- Explorer's Pack (10 GP), lines 5839-5842: Backpack, Bedroll, 2 flasks of Oil,
  10 days of Rations, Rope, Tinderbox, 10 Torches, Waterskin.
- Druidic Focus, lines 5877-5890: "Wooden staff (also a Quarterstaff) 4 lb.
  5 GP"; a Druid or Ranger can use it as a Spellcasting Focus.

Delivered (data only, existing generic path): `explorers_pack` appended to
Druid and Monk `starting_equipment`. No code, loader, save field or migration
changed. Option A now owns exactly: Druid Leather Armor, Shield, one Explorer's
Pack, one Herbalism Kit, 9 GP; Monk Spear, 5 Daggers, the chosen tool, one
Explorer's Pack, 11 GP. Option B owns no item and 50 GP. The pack is one copy
and expands once through `Inventory.expand_pack_instance` (the method behind
the room "expand pack" control) into the exact 27 SRD items; a second
expansion is refused.

Not delivered (blockers):

- **Sickle.** Adding it auto-equips it beside the Shield, leaving no free
  hand for components. Logic then fails two Water Walk checks in
  `src/dungeon/local_room_checks.gd` (a default-created Druid casting),
  which is outside this lane. Granting it needs either that fixture updated or
  a decision that starting weapons are not auto-equipped when they would block
  spellcasting. Not changed here.
- **Druidic Focus (Quarterstaff).** No item is both: `quarterstaff` is an
  ordinary weapon, `wooden_staff` is a type-`tool` focus with no weapon
  profile. `Inventory._is_compatible_spellcasting_focus` is an item-ID and
  class-ID list and `has_spellcasting_focus` only scans the backpack, so an
  equipped weapon-focus would stop counting. A real item needs a generic focus
  declaration plus an equipped-slot consumer in spell component rules, larger
  than this task. Neither stand-in is granted (asserted).

Checks (Linux Godot 4.7.2 headless, sequential):

- Logic: 6935 passed, 0 failed. `ClassToolItemChecks` adds exact package,
  gold-branch, pack expansion/second-expansion/restore and neutral renamed
  class (`kit_package_probe`, Druid data copy) checks.
- `class_tool_items_flow` 35 ok / `class_tool_items_reload` 23 ok (fresh
  process): exact owned copies in review and after Confirm, Back/cancel,
  Random, seat reset, invalid option refusal, repeat-creation refusal, one
  Monk pack expanded before saving, party and player-only two-round reload.
- Old saves: `data/fixtures/tool_items/main_382ca63_party.sav` was written by
  main 382ca63 (`class_tool_items_flow`). Party and player-only copies load,
  save, reload in a fresh process with byte-identical inventories and save
  again; no Explorer's Pack added. The 897d994 fixture also gets none.
- Also passing: class_proficiency_creation_flow/reload,
  class_skill_selection_flow/_b/reload, normal_creation_matrix (1-4 players),
  monk_action_flow, and the 16-scenario integration suite.
