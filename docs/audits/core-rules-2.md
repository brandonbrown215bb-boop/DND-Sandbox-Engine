# Core rules audit, batch 2: conditions in monster AI and non-EventResolver check/save hosts (SRD 5.2.1)

- **Commit audited:** `ede0a3cdfa66f21b0b3415f498c2e186e56a0db4` (origin/main, "Merge pull request #60")
- **Registry hash:** sha256(`str(DataLoader.get_registry_hash())`) = `70a83cc74e530743e90f8fadc992bd0651f56b51cb84b06cd73fcaf22187845e`
- **Loader:** 14 classes, 9 races, 289 items, 362 spells, 481 monsters, 0 validation failures
- **Probe:** `res://tools/core_rules_2_audit/core_rules_2_probe.tscn` (`tools/core_rules_2_audit/export_core_rules_2_probe.gd`), Godot 4.7.2 headless on Linux. Output is in `.artifacts/core-rules-2/runtime.json` (git-ignored). Rates come from 400 trials each.
- **Not run:** the Windows runner was unreachable. These are Linux headless results only.
- **Scope:** (a) how SRD conditions drive monster AI and monster turns beyond the attack-mode block at `combat_state.gd` 1538–1570, which batch 1 covered; (b) every d20 check, contest or save host outside `EventResolver`. Condition effects that come from a specific spell or feature (Dazed, Abjure Foes, Turn Undead, Charm Person tracking, Resilient Sphere and so on) are skipped. Spell and feature callers appear below only as consumers of a generic host.
- **Placeholders:** new gaps use core-6..9 (assigned S-246–S-248 in wave 2; core-9 unused). Batch 1's S-235–S-239 (core-1..5) (branch `audit/core-rules`, `docs/audits/core-rules.md`) are referenced, not repeated. No shared registers were edited.

Legend: P = runtime probe, S = static read. Classes: OK / PLANNED (real ID) / BATCH1 (S-235–S-239 (core-1..5)) / MISSING-HOST / GAP / SOURCE-GAP.

## A. Monster AI and monster turn (`src/ai/ai_controller.gd`, `src/combat/ai_command.gd`, `combat_state.gd` 1071–1305)

| # | SRD 5.2.1 clause | Engine behaviour | Evidence | Class |
|---|---|---|---|---|
| A1 | Incapacitated (and Paralyzed, Stunned, Unconscious, which include it): no actions or Bonus Actions | AI returns `none` for paralyzed, stunned, incapacitated and unconscious. The turn also skips on stunned/paralyzed (1098), unconscious (1227) and incapacitated (1240). | P `ai.monster_{paralyzed,stunned,incapacitated,unconscious}` = none | OK |
| A2 | Petrified: Incapacitated, Speed 0 | **A petrified monster is not skipped.** The AI list and all three turn gates omit `petrified`. The monster attacks normally. | P `ai.monster_petrified` = attack Near. S: no `petrified` token in combat_state.gd, ai_controller.gd or fighter_rules.gd | GAP S-246 (core-6) |
| A3 | Speed 0 for Grappled, Restrained, Paralyzed, Petrified and Unconscious. Stunned itself does not reduce Speed (SRD p.189). | `FighterRules.monster_speed` returns 0 only for paralyzed, stunned, resilient_sphere and power_word_stun. `AICommand` (line 67) and the AI (line 68) gate movement on that value alone. Restrained, grappled and petrified monsters walk. **DEV:** generic Stunned incorrectly sets Speed to 0; its Incapacitated consequence blocks actions, Bonus Actions and Reactions, not movement. | P `monster_speed_hexes`: restrained 6, grappled 6, petrified 6, unconscious 6, stunned 0 | GAP S-246 (core-6) (Grappled itself is BATCH1 S-236 (core-2)) |
| A4 | Prone: stand up costs half Speed; not possible with Speed 0 | Turn start (1081) always erases monster Prone and halves movement. This runs before the unconscious skip, so an Unconscious or Speed-0 monster still stands. | S 1081–1084 versus 1227 | GAP S-246 (core-6) (the stand-up rule itself is BATCH1 S-239 (core-5)) |
| A5 | Frightened: can't willingly move closer to the source | Only the Abjure Foes marker restricts approach (`abjure_foes_forbids_movement_closer`). A generic `frightened` monster with `condition_sources` still paths toward and attacks its source. | P `ai.monster_frightened` = attack; S 1273/1288 | GAP S-246 (core-6) (the attack Disadvantage half is BATCH1 S-235 (core-1)) |
| A6 | Charmed: can't attack the charmer or target it with damaging effects | AI target exclusion (`_is_charm_caster`) recognises only `charm_person`/`charm_monster` SpellEffects records and Animal Friendship ids. A generic charmed source is ignored. | P `ai.monster_charmed_source_near` = attack Near | GAP S-246 (core-6) |
| A7 | Invisible / hidden target: attacker must guess the location; Disadvantage | Target selection is nearest-by-distance with no perception filter, so the AI always picks the invisible or hidden PC's exact hex. The attack roll then gets Disadvantage (1528–1532, OK). | P `ai.target_near_{invisible,hidden}` = attack Near | GAP S-246 (core-6) (Hide/Search are BATCH1 S-237 (core-3)) |
| A8 | Blinded monster | Targets normally; attacks get Disadvantage (batch 1). There is no "can't see" filter for sight-dependent spells in `_choose_offensive_spell`. | P attack; S 155–175 | GAP S-246 (core-6) (spell sight requirement relates to V-003) |
| A9 | Poisoned monster | Turn start deals 1d4 poison damage (1085). This is the same non-SRD deviation batch 1 found on the player side. | S 1085–1095 | BATCH1 S-235 (core-1) |
| A10 | Exhaustion on monsters | Monster dictionaries have no exhaustion field or consumer. | S | SOURCE-GAP / BATCH1 S-235 (core-1) (monster side unspecified) |
| A11 | Opportunity attacks along a monster's path | `_check_opportunity_attacks_for_path` runs before each move (1278/1292). | S | OK |

## B. Check, contest and save hosts outside EventResolver

Reference behaviour (S/P):
- `EventResolver.resolve_skill_check` applies proficiency, expertise and exhaustion via `get_skill_check_modifier` (character.gd 895). It does **not** apply poisoned, frightened or blinded modes (P: `event_resolver_check.*.roll_mode` = normal). That belongs to BATCH1 S-235 (core-1).
- Help exists only as familiar help. Generic Help is BATCH1 S-237 (core-3), and helper modifiers are PLANNED S-097/VS-65.

| # | Host | Used by (non-spell/feature) | Conditions | Exhaustion | Adv/Dis | Help | Proficiency | Class |
|---|---|---|---|---|---|---|---|---|
| B1 | `Character.saving_throw_test_to_dc` / `make_saving_throw_result` (character.gd 1730, 2995) | Concentration (spell_encounter_lifecycle 230, shared_step_executor 2492), survival starvation CON (survival_rules 24), local-room hazard saves (local_room_rules 485–696), Sanctuary repels | **No STR/DEX auto-fail** (P: paralyzed, stunned, unconscious, petrified DEX vs DC 2 = 1.00). **No restrained DEX Disadvantage** (P 0.43 vs 0.47 baseline, noise) | Yes, −2/level (P 0.36 vs 0.47) | Caller flags + feature advantage | n/a | Yes | Auto-fail and restrained: BATCH1 S-235 (core-1). Host unification: GAP S-247 (core-7) |
| B2 | `BarbarianRules.roll_monster_save_result` (barbarian_rules 154) | combat_action 133/156/166/892/925, combat_state 3688/4699/4705/5773, fighter_rules 338, paladin_rules 38, cleric_rules 102, spell_control_resolver 30, spell_encounter_lifecycle 383 | **None:** no auto-fail (P paralyzed, stunned, unconscious, petrified DEX vs DC 2 = 1.00) and no restrained DEX Disadvantage (P 0.57 vs 0.53). Only `spell_save_resolver` 52–62 adds them, for spells. | No monster exhaustion | Caller flags, Beacon, Staggered | n/a | Stat-block `saving_throw_bonuses` | GAP S-247 (core-7) |
| B3 | Raw `Dice.roll(20)` monster saves in `monk_rules.gd` 115/124/140 (Topple, Push, Quivering Palm) | Bypass B2 entirely: no roll tokens, Bless/Bane or condition hooks | None | — | None | — | Bonus only | GAP S-247 (core-7) (host bypass; the features themselves are out of scope) |
| B4 | Overworld camp ambush Stealth (`overworld_state.gd` 414, `_party_best_stealth_mod` 442) | Wilderness rest | None | **Not applied** | None | None | **Broken:** tests `"STEALTH" in skill_proficiencies`, but proficiencies are stored title-case (`"Stealth"`). Proficiency is never added (P: `matches_STEALTH_literal` false; engine modifier 4 vs host modifier 2). Expertise is ignored. | GAP S-248 (core-8). The noncombat host family is PLANNED S-224. |
| B5 | Cunning Action Hide, two branches (combat_state 5119 and 5144) | Rogue | None | Not applied | None | — | 5119 adds proficiency; **5144 omits it**. Both use DC 12. | BATCH1 S-237 (core-3) (Hide DC 15). The inconsistent modifier is folded into S-248 (core-8). |
| B6 | Monster escape from restraining zone (combat_state 1501) | Monster Action to break Restrained | None (a poisoned monster has no check Disadvantage) | — | None | — | Stat-block Athletics | GAP S-248 (core-8) |
| B7 | `TetherRules` escape and rescue (tether_rules 306/378) | PC path → EventResolver (inherits its gaps). Monster path (308/379) is raw d20 + best modifier. | Monster path: none | — | None | None | Stat-block skills | PC: PLANNED S-168. Monster path: GAP S-248 (core-8). |
| B8 | `ContainmentRules` escape (containment_rules 316), local-room lock/pry and Entangle/Tentacles escapes (local_room_rules 660–757), zone escape (combat_state 6487) | → EventResolver | Inherits EventResolver (no poisoned/frightened) | Yes | Grants only | Familiar only | Yes | OK host; condition modes BATCH1 S-235 (core-1) |
| B9 | Death saves (`Character.make_death_save` 3028, combat_state 959–980) | Downed PCs | — | Yes, −2/level (3039) | Survivor/Beacon advantage, roll tokens | — | — | OK; PLANNED S-093/VS-113 |
| B10 | Concentration DC (spell_encounter_lifecycle 212–232) | — | Incapacitated end is checked only on damage | Via B1 | Extended Spell advantage | — | Via B1 | DC OK; incapacitated end is BATCH1 S-235 (core-1) |
| B11 | Initiative: created actors (created_command_rules 287), shared groups (initiative_tracker 88), PC initiative (combat_state 813) | — | Invisible/Incapacitated initiative modes absent | PC yes (813); created actors no | None | — | — | Invisible-initiative is BATCH1 S-235 (core-1). Created-actor exhaustion: SOURCE-GAP (created actors carry no exhaustion). |
| B12 | `event_dialog.gd` 263 | → EventResolver | as B8 | | | | | OK host |

## Proposed gaps

| ID | Source clause (SRD 5.2.1) | Affected | Reusable pieces | Depends on | Finish line |
|---|---|---|---|---|---|
| S-246 (core-6) | Rules Glossary: Incapacitated, Petrified, Restrained, Grappled, Unconscious, Stunned, Prone, Frightened, Charmed, Invisible (pp. 177–191) | `AIController.get_monster_action`, `AICommand.from_decision`, `FighterRules.monster_speed`, monster turn start (combat_state 1071–1100) and `_run_monster_ai` (1221–1305) | `Character.is_incapacitated` condition list; `condition_sources`; `CombatPerception.can_see_target`; `CombatAction.is_invisible` / `can_perceive_invisible`; the existing Abjure Foes approach check as a template | BATCH1 S-235 (core-1), -2, -3, -5 | A petrified monster takes no action. `monster_speed` is 0 for Restrained, Grappled, Petrified and Unconscious. Generic Stunned and Incapacitated alone retain normal movement, including through the AI turn path, while actions, Bonus Actions and Reactions remain unavailable. Prone stand-up happens only when the monster is conscious and has enough Speed. A generic Frightened monster refuses moves that bring it closer to any recorded source. The AI never targets a generic Charmed source with an attack or a damaging spell. The AI does not pick an unseen target's hex unless it can perceive it (or it chooses by a documented guess rule). Sight-requiring spells are not chosen while the monster is Blinded. A probe shows each case under both AI behaviours. |
| S-247 (core-7) | Paralyzed/Stunned/Unconscious/Petrified "automatically fail STR and DEX saves"; Restrained "Disadvantage on DEX saves" | `BarbarianRules.roll_monster_save_result`, `Character.make_saving_throw_result`, and the raw monk save rolls (monk_rules 115/124/140) | `spell_save_resolver.gd` 52–62 logic (lift it into the shared hosts) | BATCH1 S-235 (core-1) for the condition semantics | Every monster and character save outside the spell path applies auto-fail and restrained Disadvantage from one shared owner. `spell_save_resolver` uses that owner instead of its private copy. The monk saves call `roll_monster_save_result`. Probe: a paralyzed monster's DEX save vs DC 2 has a 0% success rate on the generic, spell and monk paths, and restrained DEX saves are rolled with Disadvantage. |
| S-248 (core-8) | Ability Checks (p. 6); Skills; Exhaustion (p. 182); Poisoned/Frightened check Disadvantage | Overworld ambush Stealth, both Cunning Hide branches, monster zone escape (combat_state 1501), monster tether escape/rescue (tether_rules 308/379) | `EventResolver.resolve_skill_check` for PCs; a new monster-check helper mirroring `roll_monster_save_result` (stat-block skills plus condition modes plus roll tokens) | BATCH1 S-235 (core-1) (condition modes), -3 (Hide DC/Help); PLANNED S-224 | No production raw `Dice.roll(20)` remains for checks. PC checks go through EventResolver, so proficiency and expertise (the "Stealth" casing fix), exhaustion and modes apply. Monster checks use the one helper. Probe: a proficient PC's ambush modifier equals `get_skill_check_modifier("Stealth","DEX")`, and a poisoned monster escape rolls with Disadvantage. |
| core-9 (unused) | none | — | — | — | **Not used.** No further distinct gap in scope. |

## Items already planned under real IDs
S-224 (noncombat check-modifier hosts, V-014) for B4/B8. S-168 (VS-136/147, V-064) for tether escapes B7. S-093 (VS-113) for death saves B9. S-097 (VS-65) for helper modifiers. V-003 for sight requirements A8.

## Coverage
**Reviewed:**
- All of `ai_controller.gd`.
- `ai_command.gd` movement gates.
- Monster turn start and `_run_monster_ai` (combat_state 1071–1305).
- `_execute_monster_attack` preamble (1515–1570, attack modes as batch 1).
- `FighterRules.monster_speed`.
- Every production `Dice.roll(20)` / `saving_throw_test_to_dc` / `roll_monster_save*` / `resolve_skill_check` / death-save call site listed in B (grep over `src/**/*.gd`, excluding `*_checks.gd`, `*_controls.gd`, `*_flow.gd`, harness, probe and test_runner files).

**Unreviewed:**
- `_move_turned_undead_away` and the `combat_command` forced commands (feature-sourced).
- `_choose_offensive_spell` target-condition interactions beyond A8.
- `CombatPerception` internals.
- `combat_action.gd` 1283 reroll (feature-specific).
- `shared_step_executor` 2349 spell-step saves.
- Surprise/initiative modes.
- The test, harness and `*_checks` files.
- The Windows runner (unreachable).

## Totals
- 23 rows: A1–A11 and B1–B12.
- OK: 6 (A1, A11, B8, B9, B12, plus the B10 DC).
- GAP: 10 rows feeding 3 new placeholders (S-246 (core-6), -7, -8).
- BATCH1 references: 9.
- PLANNED: 5 IDs (S-224, S-168, S-093, S-097, V-003).
- SOURCE-GAP: 2 (A10, B11 created actors).
