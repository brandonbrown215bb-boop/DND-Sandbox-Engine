# Batch 084 build: stale scenario fixture repair

**Finish line (verbatim):** "Fix the remaining two-monster assumptions; prove the component/focus and casting-permission diagnoses using representative failures, then repair affected fixtures. Run the supported Windows checks. Don't weaken game rules to make tests green."

**Scope: partial as declared.** Only fixtures in `src/viewport_harness.gd` changed. No game rule, data or engine code changed.

## Diagnoses and repairs
- **R1, two-monster assumptions:** scenarios that index a second monster now spawn `["goblin","goblin"]`. Representative failures from the triage (`barbarian_choice_flow`, `cleric_action_flow`, `cleric_strike_flow`, `core12_shared_rules`, `faerie_fire_spell_flow`, `spell_cast_stage_flow`) all failed with `Invalid access of index '1' on Array[Dictionary]`. All of them pass now.
- **R2, components/focus (SRD "Components"; Batch 048 rule):** `_ready_spell_components()` gives fixture casters a component pouch and frees one hand, the same setup a real caster would have. The hand and focus rule itself is unchanged. Representatives: `mage_armor_spell_flow`, `death_ward_spell_flow`, `sanctuary_spell_flow` and `spirit_guardians_spell_flow` now pass.
- **R3, casting permission (aee56c0):** `_own_class_spells()` records the class `feature_choices` that character creation would record. `_menu_spell()`/`_cast_menu_spell()` cast the real HUD menu row, which carries `_source_permission_id`. If a fixture has no permission, it falls back to the raw record so the failure stays visible (`MENU_SPELL_MISS`). Representatives: `true_strike_spell_flow`, `goodberry_spell_flow`, `sleep_spell_flow` and `action_history_flow` now pass.

## Failures that flipped to PASS (28; first error from the 2026-10-25 triage)
| Scenario | Triage first error (#47 stack) |
|---|---|
| `action_history_flow` | [FAIL] [action_history_flow] Canceling real spell targeting records no action and spends no Bonus action |
| `attack_result_adjustment_flow` | SCRIPT ERROR: Trying to assign value of type 'Object' to a variable of type 'Dictionary'. |
| `barbarian_choice_flow` | SCRIPT ERROR: Invalid access of index '1' on a base object of type: 'Array[Dictionary]'. |
| `barkskin_spell_flow` | [FAIL] [barkskin_spell_flow] Casting Barkskin on a willing party target applies AC 17 and spends its slot |
| `batch_i_review_flow` | [FAIL] [batch_i_review_flow] Normal picker honors scoped prevention bypass across target Sphere and pays original slot/action once (HP=100 l |
| `beacon_of_hope_spell_flow` | [FAIL] [beacon_of_hope_spell_flow] Beacon selects a downed ally and enemy creature within 30 feet; excludes distant creatures; and spends on |
| `cleric_action_flow` | SCRIPT ERROR: Invalid access of index '1' on a base object of type: 'Array[Dictionary]'. |
| `cleric_strike_flow` | SCRIPT ERROR: Invalid access of index '1' on a base object of type: 'Array[Dictionary]'. |
| `core12_shared_rules` | SCRIPT ERROR: Invalid access of index '1' on a base object of type: 'Array[Dictionary]'. |
| `darkvision_spell_flow` | [FAIL] [darkvision_spell_flow] A touched willing party creature gains source-owned Darkvision |
| `death_ward_spell_flow` | [FAIL] [death_ward_spell_flow] Death Ward spends one fourth-level slot and one Magic Action on a touch-range ally |
| `detect_poison_and_disease_spell_flow` | [FAIL] [detect_poison_and_disease_spell_flow] The spell reports tracked Poisoned conditions and venomous attacks while excluding ordinary cr |
| `divine_favor_spell_flow` | [FAIL] [divine_favor_spell_flow] Divine Favor casts as a Bonus Action; spending one level-1 slot and creating its timed effect |
| `faerie_fire_spell_flow` | SCRIPT ERROR: Invalid access of index '1' on a base object of type: 'Array[Dictionary]'. |
| `fighter_progression` | SCRIPT ERROR: Invalid access to property or key 'inventory' on a base object of type 'Nil'. |
| `goodberry_spell_flow` | [FAIL] [goodberry_spell_flow] Goodberry creates ten saved berries with a 24-hour expiry and spends its spell slot |
| `grease_spell_flow` | [FAIL] [grease_spell_flow] A live Grease cast creates its seven-hex area |
| `mage_armor_spell_flow` | [FAIL] [mage_armor_spell_flow] Casting Mage Armor sets 13 + Dexterity AC and spends its level-1 slot |
| `magic_weapon_spell_flow` | [FAIL] [magic_weapon_spell_flow] A fourth-level Magic Weapon spends its slot and Magic Action and establishes Concentration on the ally's eq |
| `mass_cure_wounds_flow` | [FAIL] [mass_cure_wounds_flow] Mass Cure Wounds asks which creatures in its Sphere to heal |
| `s026_relationship_willingness_flow` | [FAIL] [s026_relationship_willingness_flow] Unknown target refuses the neutral loaded effect while the supported cast settles one slot and o |
| `sanctuary_spell_flow` | [FAIL] [sanctuary_spell_flow] Sanctuary spends a first-level slot and Bonus Action to ward an ally |
| `shared_distance_predicate_flow` | [FAIL] [shared_distance_predicate_flow] Actual neutral actor-relative consumer includes exact 10-foot equality and spends one slot plus Magi |
| `shared_fact_predicate_flow` | [FAIL] [shared_fact_predicate_flow] Actual neutral spell picker keeps its effect off at HP 25 while paying one slot and Magic action |
| `sleep_spell_flow` | [FAIL] [sleep_spell_flow] Sleep asks which creatures to include and resolves a save only for the chosen creature |
| `spell_cast_stage_flow` | SCRIPT ERROR: Invalid access of index '1' on a base object of type: 'Array[Dictionary]'. |
| `spirit_guardians_spell_flow` | [FAIL] [spirit_guardians_spell_flow] A fifth-level cast creates the alignment-damage Emanation for 10 minutes without striking its caster im |
| `true_strike_spell_flow` | [FAIL] [true_strike_spell_flow] True Strike is selected and held in live targeting state |

## Results
- Logic suite (Linux): **6355 passed, 0 failed**.
- Import ran twice, both rc=0, with 0 SCRIPT/Parse/Compile lines. No tracked `.translation` files.
- Full scenario sweep, 247 scenarios, Linux, one Godot process at a time. Before (#47 stack triage): 167 PASS / 74 FAIL / 6 TIMEOUT. After: **197 PASS / 47 FAIL / 3 TIMEOUT**. Main triage for reference: 157/66/5 of 228.
- In the sweep, one scenario went PASS→FAIL (`shared_spell_normal_controls_flow`) and two went PASS→TIMEOUT (`wave_three_foundations_flow`, `final_encounter_round_trip`). Rerun alone, all 3 PASS, so these are being treated as flaky, not regressions.

## Supported Windows checks
`docs/testing.md` and `README.md` define the supported gate as `run_tests.ps1` on Godot 4.7.x **on Windows**. **Windows was not run here.** I ran the Linux equivalent (`run_tests.sh`, Godot 4.7.2 Linux headless). Someone on a Windows host still needs to run `.\run_tests.ps1 -Suite logic` and the integration scenarios.

## Still failing: need investigation (causes not claimed)
Unresolved gameplay areas: concentration cleanup, aura exit, typed next-hit grants, repeated damage settlement. The batch_067–075 `*_reload` pairs fail because the triage harness loses their paired save data, as the triage report describes. `shared_entity_binding_flow` hits a SCRIPT ERROR at combat_hud.gd:2489 (null tree in request_roll_token_replacement). It was already failing before this batch and is left for investigation.

Remaining non-PASS: `bard_action_flow` (FAIL), `batch_020_suppression_aura_flow` (FAIL), `batch_067_weapon_damage_choice_reload` (FAIL), `batch_068_exact_contents_reload` (FAIL), `batch_069_unknown_weight_reload` (FAIL), `batch_070_attack_ac_upgrades_reload` (FAIL), `batch_071_monster_max_hp_reload` (FAIL), `batch_072_last_charge_reload` (FAIL), `batch_073_explicit_death_reload` (FAIL), `batch_074_work_site_reload` (FAIL), `batch_075_linked_removal_reload` (FAIL), `chain_lightning_mixed_targets_flow` (FAIL), `chain_lightning_target_identity_flow` (FAIL), `child_group_flow` (FAIL), `class_level_table_flow` (FAIL), `cloud_of_daggers_spell_flow` (FAIL), `damage_history_flow` (FAIL), `detect_evil_and_good_spell_flow` (FAIL), `enhance_ability_spell_flow` (FAIL), `failed_save_numeric_bonus_flow` (FAIL), `final_encounter_round_trip` (TIMEOUT), `fire_area_object_ignition_flow` (FAIL), `formula_number_flow` (FAIL), `heroism_spell_flow` (FAIL), `identify_spell_flow` (FAIL), `invisibility_spell_flow` (FAIL), `jump_spell_movement` (FAIL), `local_room_object_flow` (FAIL), `meteor_swarm_object_area_flow` (FAIL), `mixed_mechanics_encounter` (FAIL), `post_roll_die_bonus_flow` (FAIL), `ranger_action_flow` (FAIL), `ranger_natures_veil_blindsight` (FAIL), `result_reducer_continuation_flow` (FAIL), `result_reducer_flow` (FAIL), `roll_token_normal_controls_flow` (FAIL), `s029_save_context_flow` (TIMEOUT), `shared_entity_binding_flow` (FAIL), `shared_margin_hp_gate_flow` (FAIL), `shared_next_melee_hit_grant_flow` (FAIL), `shared_prior_result_identity_flow` (FAIL), `shared_spell_attack_bonus_flow` (FAIL), `shared_spell_normal_controls_flow` (FAIL), `shared_spell_outcome_maps_flow` (FAIL), `shared_spell_p1_flow` (FAIL), `sorcerer_subtle_spell` (FAIL), `sorcerer_twinned_spell` (FAIL), `ward_normal_controls_flow` (FAIL), `wave_three_foundations_flow` (TIMEOUT), `wizard_capstone_cast_modes` (FAIL).

## Mechanics contract / slice boundary
No mechanics contract changed, because this is fixture-only. Slice boundary: fixtures only. The gameplay failures above are out of scope.
