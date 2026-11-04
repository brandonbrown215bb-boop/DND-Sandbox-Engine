# Druidic Focus (Quarterstaff) and Sickle — Druid option A complete

Base: main `de3891d`. Branch `codex/druid-focus-sickle`. Runtime Builder,
2026-11-03. One PR, no stack.

## Source clauses (SRD 5.2.1, `/workspace/srd.txt`)
- Druid Starting Equipment, 2500-2504: "(A) Leather Armor, Shield, Sickle,
  Druidic Focus (Quarterstaff), Explorer's Pack, Herbalism Kit, and 9 GP; or
  (B) 50 GP".
- Druid Spellcasting Focus, 2582: a Druidic Focus. Ranger, 3501: can use a
  Druidic Focus.
- Sickle, 5478: 1d4 Slashing, Light, Nick, 2 lb., 1 GP. Quarterstaff: 1d6
  Bludgeoning, Versatile (1d8), 4 lb.
- Druidic Focus, 5877-5887: "A Druid or Ranger can use such an object as a
  Spellcasting Focus." "Wooden staff (also a Quarterstaff) 4 lb. 5 GP".
- Somatic, 6382-6386: "must use at least one of their hands".
- Material, 6388-6404: "must have a hand free to access them, but it can be the
  same hand used to perform Somatic components"; a focus must be held; a
  priced or consumed material must be supplied as specified.

## Delivered
- `weapons.json`: new `druidic_focus_quarterstaff` (simple, 1d6 bludgeoning,
  versatile 1d8, 4 lb., 5 GP) with `"spellcasting_focus_kind": "druidic"`.
  Appended last so manifest indexes do not shift.
- `druid.json` option A: Leather Armor, Shield, Druidic Focus (Quarterstaff),
  Sickle, Explorer's Pack, Herbalism Kit, 9 GP; option B 50 GP, no items. The
  focus is listed before the Sickle so the existing `add_starting_equipment`
  placement holds the focus (first weapon) and carries the Sickle. No new
  equip rule.
- `druid.json` / `ranger.json`: `"spellcasting_focus_kinds": ["druidic"]`.
- `DataLoader`: refuses `spellcasting_focus_kind` that is not a non-empty
  string on a `weapon` item, and `spellcasting_focus_kinds` that is not a list
  of non-empty strings.
- `Inventory.held_spellcasting_focus(class_id)`: the item equipped in Weapon or
  Off-hand whose kind is in the class declaration. Consumer:
  `has_required_spell_component`: when such a focus is held, a spell with a
  Somatic component, or a Material component that is neither consumed nor
  priced, passes. The hand holding the focus performs Somatic and Material
  (SRD Material 6388-6404: "can be the same hand used to perform Somatic
  components"). This was ruled by Brandon (D1, follow-up to review 5758273130). Every existing caller (combat menu preflight
  `spell_cast_validation`, resolver, combat action, room casting) uses it
  before payment. No class/item ID branches, no registry, no new service.
- Shield + held focus therefore casts V,S spells (Cure Wounds, Produce Flame,
  Entangle...) with no free-interaction control. A plain weapon (Sickle,
  plain Quarterstaff) or a stowed focus does not count.
- Unchanged: priced/consumed materials
  (e.g. Revivify diamond) keep exact-copy and free-hand rules; a stowed focus is
  not held; plain `quarterstaff` is not a focus; the native backpack
  focus/pouch path is unchanged.

## Not delivered / gaps (outside lane, named not stood in)
- Shillelagh checks weapon IDs `club`/`quarterstaff`
  (`spell_cast_validation.gd:225`, `combat_action.gd:2449`) — it will not
  accept the focus staff.
- Fighter Weapon Mastery (`fighter_rules.gd:10`) and Monk simple-melee list are
  item-ID keyed — the focus staff gets no Topple mastery / Monk weapon status.
- Shillelagh / Topple base weapon (D2, deferred by Brandon): the focus isn't
  yet recognized as a Quarterstaff for Shillelagh or Topple. This PR leaves
  `combat_action.gd` untouched and adds no base-weapon field.
- The 8 `_ready_spell_components` fixture repairs from the first head are
  removed; those scenarios pass with the default option A Druid.

## Checks (Linux Godot 4.7.2 headless, sequential)
- Logic: 6951 passed, 0 failed (base de3891d: 6935). `ClassToolItemChecks`
  adds the focus profile, Shield+focus V/S/M and V/S (Cure Wounds, Produce
  Flame) allowed, Sickle+Shield / plain Quarterstaff V/S refused, Gentle
  Repose (consumed, unpriced) refused with the focus held (mutation proof:
  dropping `consumed` from the guard gives 6950 passed, 1 failed), Ranger
  allowed / Wizard refused, Revivify without and with the diamond, Sickle
  equipped through `equipment_control_equip` refused, stowed focus refused,
  re-equip restores, plain Quarterstaff refused, neutral renamed item+class
  (`focus_probe_staff` / `focus_probe_class`) works and fails without the
  class declaration, loader refusals, restore keeps the held copy.
- `druidic_focus_cast_flow` (new) 16 ok: real room Equip control swaps in the
  Sickle → "Cast Water Walk" refused, slot unspent; Equip the focus → cast
  spends one level-3 slot; repeated press pays nothing and consumes no gear.
  Combat (player controls only, default option A Druid): Sickle equipped via
  the combat Equip control → Cure Wounds refused, slot + Action unspent;
  re-equip the focus; Produce Flame with Shield + focus spends the Bonus Action
  once and no slot; Cure Wounds heals, spending exactly one slot and the
  Action. Ice Knife
  selected without payment, cancelled with nothing spent, then cast spending
  exactly one slot and the Action.
- `class_tool_items_flow` 44 ok / `class_tool_items_reload` 29 ok: review lists
  one Druidic Focus (Quarterstaff) and one Sickle and no plain Quarterstaff;
  Confirm holds focus + Shield and carries the Sickle; Back/cancel, Random,
  seat reset, invalid and repeated choices; party and player-only two-round
  fresh-process reload.
- Old saves: `data/fixtures/tool_items/main_de3891d_party.sav` written by main
  de3891d (`class_tool_items_flow`). Party and player-only copies load, save,
  reload in a fresh process with identical inventories, and save again; no
  focus or Sickle added. The 897d994 and 382ca63 fixtures also pass (rerun after
  the follow-up).
- Also passing: goodberry, entangle, plant_growth, conjure_animals/fey/
  woodland_beings, antilife_shell, mass_cure_wounds, owned_creature_lifecycle,
  moonbeam, barkskin, spike_growth, freedom_of_movement, check_context,
  batch_h_review, party_recovery, batch_085, character_creation,
  class_proficiency_creation, class_skill_selection, save_load,
  character_sheet, crown_composition_solo_two/three_four, crown_smoke,
  combat_ai_loop, party_combat, playtest_fixes, main_menu_load, dungeon,
  class_building_blocks, core12_shared_rules/audit_repairs,
  normal_creation_matrix (1-4 players).
- Pre-existing on base de3891d too (not caused here): ranger_action_flow
  (Favored Enemy Hunter's Mark), local_room_object_flow (combat movement modes,
  uphill cost; Find Steed mount check is flaky on both).
