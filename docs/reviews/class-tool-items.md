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
