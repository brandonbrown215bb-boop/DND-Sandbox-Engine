# Core rules and conditions status (SRD 5.2.1)

Audit of the core rules in scope (action economy; Hide/Search/Invisible/obscurement; grappling; cover; light and obscurement; movement; falling; concentration; 0 HP, Death Saves and stabilizing; rests; Exhaustion), plus all 15 SRD conditions. Measured against SRD 5.2.1 *Playing the Game* (pp. 5–19) and the *Rules Glossary* (pp. 176–192).

The original audit below is a historical snapshot. Current runtime changes
are summarized next. Supplement rules stay out of scope.

## Current condition implementation (2026-10-29)

The audit tables below retain their original commit/probe evidence, rather than
claiming new results for clauses that have not been exercised. The current
`CombatAction.CONDITION_RULES` table supplies shared condition consequences to
generic Character/monster queries. Character and monster saves now use the same
auto-failure and save-mode checks. The spell adapter passes uncanceled modes to
that owner; it must not cancel Restrained against Advantage and then add the
condition a second time. Monster save receipts retain the d20 mode, base modifier
and separate signed Bless/Bane dice. Automatic failures bypass dice, roll-token
replacement and optional save bonuses/rerolls. The actual Open Hand Flurry hit chooser now routes Topple/Push through this
owner, retaining automatic outcomes, Restrained modes and captured Bless/Bane.
Quivering Palm remains unavailable at level 17 and unproven through a player action. Character checks and the monster-check helper apply
condition modes, and combat escape/check callers provide live participant
context for fear visibility, including both existing Cunning Hide branches.
Social charm Advantage uses the actual target of either actor kind. Charm/fear
use the source record's complete caster ID (including colons); native Turn Undead
uses its existing caster metadata. Removing one source preserves other sources.
Incapacitated ends concentration through the live CombatState or room owner;
outside a scene, managed concentration uses SpellEffects and its saved room-area
cleanup. CorpseRules also consults the live owner before its fallback so massive
death cleans zones/lights immediately, before concentration metadata is cleared. Unconscious drops exact held equipment copies through the live combat
or persistent-room owner, including entry into a room already Unconscious. It derives Prone without
installing a second lasting prone flag. Player turns preserve movement for
Stunned/generic Incapacitated while the HUD and turn budget refuse Actions and
Bonus Actions. Restrained/Grappled retain their action turn at Speed 0; only an
actor with neither movement nor actions skips its unusable turn. Room movement
also preserves generic Stunned/Incapacitated movement and checks fear sources
along the selected route. Poisoned no longer inflicts unconditional turn-start damage.
Healing removes the derived zero-HP unconsciousness by restoring HP; it does
not remove explicit source-owned Unconscious grants such as magical sleep, or
independent Prone grants. Damage ends only the sources whose ending rule allows
it, including the existing Cunning Strike knockout source.

AI commands revalidate live action, movement, perception, source and target facts
after choices. Ordinary monster attacks let the shared resolver own live modes;
spells refresh live positions before settling. Opportunity Attacks recheck sight,
reach and eligibility before spending the Reaction. Monster spell projections
retain the monster's stable identity, declared spell permissions and cast serial;
separate casts must not reuse one source ID. Defensive AI selects a usable ranged
profile or retreats without proposing an out-of-range melee attack.

Hide, ambush, zone and tether checks use EventResolver rather than raw d20s.
Monster checks retain mode/die/token receipts; tether escape/rescue return their
captured check as well as the outcome. Proficiency/expertise and Exhaustion enter
the modifier once. This does not expose new optional check-choice menus (S-224).

`InitiativeTracker.roll_result` is the shared initiative d20 owner for both actor
kinds, late-created actors, familiars and rolled source groups. It applies live
Invisible/Incapacitated modes and Exhaustion once. Rolled groups use the first
authored member as the representative even if a different member joins first;
owner-count/after-owner groups inherit a count without another test. Captured
rolled counts survive empty/rebuilt groups without rerolling new conditions.

Offensive monster casting retains one encounter-local Character adapter for
source lifetime, with the monster's actual identity and shared source records.
Reconciliation includes those owners; slot payment is retained across refresh.
The existing cast preparation/application and lifetime owners handle source
replacement, recipient expiry and Incapacitated/death cleanup. Typed damage
queues concentration by exact owner/source/damage occurrence, aggregating mixed
packets (including temp HP) into one shared save. Zero resolved damage has no
save; lethal damage ends concentration immediately. Pending replacement choices
serialize further damage and block new actions/turn advance; stale old-source
choices cannot pay a token or affect a replacement. All monster-owned payloads
end before encounter capture/party saves. These adapters and queues are never
serialized. This extends the existing single/multi-target monster host; AI
area/marker spell selection is separate from this condition work.

The Crown condition/roll-host work is complete. S-247 retains only inaccessible
level-17 Quivering Palm on the standard roadmap. Ordinary Prone crawling and
voluntary standing remain S-239; current conscious turn-start standing spends
half movement. A full 200-object room retains equipped gear and reports that
the drop cannot be represented, rather than losing the copy or creating an
invalid save. The [slice recovery boundary](../planning/vocabulary-slices.md#srd-condition-and-roll-host-spine)
owns acceptance, exact verification and limits.

Observer-relative sight/location, combat concealment and source-specific darkness
exceptions now use the [perception contract](perception.md). The original
Invisible/obscurement findings below are historical; the S-190/S-191 registry
boundary records current proof. Encounter initiative uses Invisible Advantage;
ordinary Hide/Search and cover remain separate.

## Evidence boundary

| Item | Value |
|---|---|
| Commit audited | `ede0a3cdfa66f21b0b3415f498c2e186e56a0db4` (main, PR #60 merge) |
| Registry snapshot SHA-256 | `70a83cc74e530743e90f8fadc992bd0651f56b51cb84b06cd73fcaf22187845e` (sha256 of `DataLoader.get_registry_hash()`, same convention as `dnd-runtime-source-ownership.json`) |
| Loader state | 14 classes, 9 races, 289 items, 362 spells, 481 monsters, 0 validation failures; 25 effectless feature records rejected (pre-existing warning) |
| Runtime | Godot 4.7.2-stable, **Linux headless** box. The Windows runner was unreachable, so no Windows run was made. |
| Probe | `godot --headless --path . res://scenes/core_rules_inventory_export.tscn` → `.artifacts/core-rules/runtime.json` + `probe.log` (ignored artifacts, not committed) |
| Probe method | Uses the production autoloads. Throwaway human fighters (STR/DEX/CON 14) receive each condition through `Character.add_condition` (Exhaustion goes through `gain_exhaustion`), and the probe reads the real owners: `get_speed`, `CombatAction.is_incapacitated`, `make_attack_roll`, `saving_throw_test_to_dc` vs DC −100 (succeeds unless auto-fail), `EventResolver.ability_check_roll_mode`, rests, `take_damage` at 0 HP. Attacks *against* a conditioned target go through `CombatAction.resolve_weapon_attack`, which does not return its roll mode, so the probe measures hit rate over 300 fresh targets against an unconditioned baseline (Character target baseline 0.33, monster AC 14 baseline 0.50; ≥ +0.12 = Advantage, ≤ −0.12 = Disadvantage). |
| Static review | Owners cited below were read at the audited commit. Lines cited without a probe value are static-only. |

Coverage: **reviewed** = every row in the tables below (15 conditions, 11 rule areas, 9 SRD actions). **Unreviewed:**
- monster-side (AI) consequences beyond `combat_state.gd` 1538–1570;
- local-room/event non-combat hosts other than `EventResolver`;
- feature/spell-specific condition riders, which are already owned by their own spell or feature registers.

## Classification legend

| Code | Meaning |
|---|---|
| OK | Existing supported behaviour matches the cited clause on the production path. |
| PLAN | Already planned. Cites the existing S-/V- row. |
| HOST | Owner exists but a host or continuation is missing; cites the existing S-/V- row. |
| GAP | Genuinely unaccounted for. A new requirement has been added (S-235…S-239, V-100, V-101). |
| DEV | The engine deliberately or accidentally does something the SRD does not. This is a correctness finding, tracked under a GAP slice. |
| SRC | Source gap (ADR-0023). Nothing found in this scope. |

## Conditions (Rules Glossary)

**Execution: native for all 15.** Condition names are code, not registry data. `Character.conditions` and monster `conditions`/`condition_sources` dictionaries hold them. `shared_spell.gd` `CONDITIONS` is only an authoring allow-list.

| Condition | SRD clauses | Engine (probe = P, static = S) | Class |
|---|---|---|---|
| Blinded | Can't see; fails sight checks; attacks against it have Advantage; its attacks have Disadvantage | Own attacks Disadvantage (P). Attacks vs a blinded Character and vs a blinded monster: **no Advantage** (P 0.26 / 0.54); only the monster-AI path grants it (S `combat_state.gd` ~1565). No sight-check auto-fail in `EventResolver`. | OK own-attack; GAP S-235 |
| Charmed | Can't attack or target the charmer with damaging abilities/effects; charmer has Advantage on social checks | Source tracking exists (`combat_state.gd` 1757, 4848–4864). No generic "can't attack the charmer" refusal and no social-check Advantage (P: own attack normal; S). | GAP S-235 |
| Deafened | Can't hear; fails hearing checks | No consumer found (P/S). | GAP S-235 (V-003 for check purpose) |
| Exhaustion | Cumulative levels; D20 Tests −2×level; Speed −5 ft×level; death at 6; Long Rest −1 | Speed 25→5 ft, dies at 6 via CorpseRules (P). Long Rest 2→1 (P). Attack, save, Death Save and Initiative −2×level (S `character.gd` 1730/1835/3028, `combat_state.gd` 813). The ability-check penalty in `EventResolver` was not confirmed. | OK; verify checks under S-235 |
| Frightened | Disadvantage on checks/attacks while source in line of sight; can't willingly move closer to source | Only Abjure Foes monster-attack LoS (S `combat_state.gd` 1553). Player attacks and checks are unaffected (P). No approach restriction. | GAP S-235 |
| Grappled | Speed 0; Disadvantage on attacks vs targets other than grappler; movable by grappler (extra cost); ends on Incapacitated/out-of-reach | **No `grappled` condition exists in production code.** `add_condition("grappled")` stores an inert flag (P: speed 30, no attack change). Restraint tethers (S-168) are a separate verified relation. | GAP S-236 |
| Incapacitated | No actions, Bonus Actions or Reactions; concentration broken; can't speak; Disadvantage on Initiative if surprised… (glossary list) | `is_incapacitated` true for incapacitated/paralyzed/petrified/stunned/unconscious (P). Reactions are refused (`reaction_triggers.gd` 74). Rage and Wild Shape end (S). **Concentration ends only at the next damage check** (`spell_encounter_lifecycle.gd` 214), not on gaining the condition. | OK partial; GAP S-235 (concentration) |
| Invisible | Surprise/Initiative Advantage; concealed (not affected by sight-needing effects unless seen); attacks vs it Disadvantage, its attacks Advantage | Attacks vs invisible: Disadvantage (P 0.10/0.28). Attacker-side Advantage is in `resolve_weapon_attack` (S). No Initiative Advantage. Observer-relative concealment is not represented. | OK attack; PLAN S-191/V-073; GAP S-235 (Initiative) |
| Paralyzed | Incapacitated; Speed 0; auto-fail STR/DEX saves; attacks vs Advantage; hit within 5 ft is crit | Speed 0, incapacitated, Advantage and auto-crit (P 0.47/0.82). Auto-fail STR/DEX only on the **spell save path** (`spell_save_resolver.gd` 60); the generic `saving_throw_test_to_dc` succeeds (P). | OK partial; GAP S-235 |
| Petrified | Transformed (+weight, no aging); Incapacitated; Speed 0; attacks vs Advantage; auto-fail STR/DEX; Resistance to all damage; Poison immunity | Incapacitated only (P). **Speed 30, no Advantage against it (P 0.29/0.57), no auto-fail, no Resistance or immunity.** | GAP S-235 |
| Poisoned | Disadvantage on attack rolls and ability checks | Own attacks Disadvantage (P). Ability checks: no Disadvantage (P). **DEV:** player turn start deals 1d4 poison damage while Poisoned (`combat_state.gd` ~989). This is not in the SRD condition. | GAP/DEV S-235 |
| Prone | Only movement is crawl or stand (half Speed); own attacks Disadvantage; attacks vs it Advantage within 5 ft, else Disadvantage | Monster targets: Advantage (P 0.79). **Character targets: none** (P 0.31). Own attacks: no Disadvantage (P). Player Speed halved for the whole turn instead of a stand-up cost or crawling (S `combat_state.gd` 1015/2219/4361). Monsters auto-stand (S 1081). Ranged Disadvantage beyond 5 ft is absent. | GAP S-235, S-239 |
| Restrained | Speed 0; attacks vs it Advantage; its attacks Disadvantage; Disadvantage on DEX saves | Speed 0 and Advantage against it (P 0.63/0.78). Own-attack Disadvantage in `resolve_weapon_attack` (S; `make_attack_roll` alone reports normal). DEX-save Disadvantage only on the spell path (S `spell_save_resolver.gd` 59); generic save normal (P). | OK partial; GAP S-235 |
| Stunned | Incapacitated; auto-fail STR/DEX; attacks vs Advantage; no inherent Speed reduction (SRD p.189) | Incapacitated, Speed 0, turn skipped (P/S). **DEV:** the Speed restriction is not part of Stunned; Incapacitated blocks actions, Bonus Actions and Reactions, not movement. Advantage only vs monster targets (P 0.85 vs Character 0.25). **No auto-fail** on any path. | GAP S-235; monster movement/turn repair S-246 |
| Unconscious | Inert: Incapacitated + Prone, drops held items; Speed 0; auto-fail STR/DEX; attacks vs Advantage; hit within 5 ft crit | Incapacitated, Advantage and crit (P 0.51/0.80). **Speed 30 when HP > 0** (P). Does not apply Prone, including at 0 HP (P `at_zero_prone=false`). No auto-fail. No item drop. | GAP S-235 |

## Rule areas (Playing the Game / Rules Glossary)

| Area | SRD clauses decomposed | Engine owner and behaviour | Class |
|---|---|---|---|
| Action economy | One Action, Bonus Action (only if granted), one Reaction per round (reset on own turn), movement split around actions, one free object interaction | `CombatTurnBudget` reset/spend (OK). Reaction reset on own turn (OK). Off-turn and type-limited budgets **PLAN S-160/V-060**; extra turns S-159. | OK / PLAN |
| SRD actions (Attack, Dash, Disengage, Dodge, Help, Hide, Influence, Magic, Ready, Search, Study, Utilize) | Each action's effect, cost and end condition | The [ordinary action continuation](ordinary-actions.md) supplies ordinary Dash/Disengage/Dodge, bounded legal Hide/creature Search and attack/stabilization Help. Class movement/defense versions reuse the effects. Dodge has owner-start expiry, defender sight, DEX-save Advantage and permanent loss on Incapacitated/effective Speed 0. Ready, proficient-check Help and broader world actions remain open. | GAP S-237 (V-101) |
| Hide / Search / hidden | Hide: DC 15 Stealth while Heavily Obscured or behind ¾/Total cover, out of sight; success = Invisible condition until found, sound or attack; Search = Wisdom check | Ordinary and Cunning Action Hide share DC 15, live heavy obscurement/Total Cover and enemy sight checks, Invisible benefits, a captured discovery DC and attack/Verbal-cast endings. Bounded creature Search uses actual Perception. Three-Quarters Cover, noise producers and room/overworld/hidden-object Search remain open; see [ordinary actions](ordinary-actions.md). | DEV/GAP S-237; PLAN S-188, S-191 |
| Light and obscurement | Lightly Obscured = Disadvantage on sight Perception; Heavily = Blinded; bright/dim/darkness; Darkvision | Fog Cloud and Darkness are modelled as attack Advantage+Disadvantage tags (`fog_cloud_obscured`/`darkness_obscured`). There is no general light-level or observer model. | PLAN S-190, S-191 (V-073) |
| Cover | Half +2 AC/DEX saves; ¾ +5; Total can't be targeted | **No cover owner found** in combat, hex or character code. | GAP S-238 |
| Speed and movement types | Walk/climb/swim/fly/burrow speeds; difficult terrain +1 ft per ft; mode switching | `physical_facts_rules.gd` modes and terrain (VS-102). Burrow and phasing **PLAN S-180**. | OK (S-179) / PLAN |
| Climbing / swimming without a speed; crawling; standing up; jumping | Extra 1 ft per ft; stand = half Speed; Long Jump = STR ft running (half standing); High Jump = 3+STR mod | A climb/swim speed of 0 refuses (`get_speed_for_mode`) instead of using walk speed at double cost. No crawl, no stand cost (see Prone), no jump. | GAP S-239 |
| Falling | 1d6 Bludgeoning per 10 ft (max 20d6); land Prone unless damage avoided; water fall rules | Forced-movement and room falls exist (`combat_state.gd` 5444, 6176). Expired flight/descent **PLAN S-181**. Prone-on-landing was not verified. | OK partial / PLAN S-181 |
| Concentration | Ends on Incapacitated, death, casting another concentration spell, or failed CON save (DC max(10, half damage), cap 30) | DC formula OK (`spell_encounter_lifecycle.gd` 226). The Incapacitated end is only checked on damage (see Incapacitated). Choices on the roll **PLAN S-226**. | OK / GAP S-235 / PLAN S-226 |
| 0 HP, Death Saves, stabilizing | Unconscious at 0; DC 10 save each turn; 3 successes stable, 3 failures dead; nat 20 regain 1 HP; nat 1 = 2 failures; damage at 0 = 1 failure (crit 2); massive damage ≥ max HP; Stabilize via Medicine DC 10 / Help | Unconscious at 0 (P). Damage at 0 → 1 failure, crit → +2 (P 1→3). Massive damage kills (P). nat 20/nat 1 (S `character.gd` 3028). `stabilize` exists (3079). Unconscious-at-0 is not Prone (S-235). | OK / GAP S-235 |
| Short Rest | 1 hour; spend Hit Point Dice (roll + CON); interrupted by combat/casting/damage; requires HP ≥ 1 | Requires HP > 0 (S). **0 HP healing** with no choice (P). **No Hit Point Dice pool** on `Character` (P). No duration or interruption. | PLAN S-071 (Hit Dice), S-070 (start/duration/interruption) via V-048 |
| Long Rest | 8 hours; regain all HP and all spent Hit Point Dice; −1 Exhaustion; one per 24 h (16 h after start); interruption (1 h+ activity / combat / damage); requires HP ≥ 1 | Full HP and −1 Exhaustion (P). Recovery blockers honored (S). No Hit Point Dice restore, no 16-hour spacing, no interruption. | PLAN S-070, S-071 (V-048) |

## Gaps grouped by shared need

| ID | Source clause (SRD 5.2.1) | Affected entries | Reusable pieces | Depends on | Finish line |
|---|---|---|---|---|---|
| S-235 (V-100) | Rules Glossary condition entries pp. 177–191; Concentration p. 179; Unconscious at 0 HP p. 17 | All 15 conditions (Blinded, Charmed, Deafened, Frightened, Incapacitated-concentration, Invisible-Initiative, Paralyzed, Petrified, Poisoned, Prone, Restrained, Stunned, Unconscious, Exhaustion checks) | `has_condition`, `is_incapacitated`, the `resolve_weapon_attack` mode pipeline, the `spell_save_resolver` auto-fail/Disadvantage line, `EventResolver.ability_check_roll_mode` contributors, `ZeroHpAftermathRules` | S-072, S-074, V-012, V-013 | One shared condition-consequence table is consulted by Character and monster attack, save, check, speed and turn owners on the same path. Removing Poisoned turn damage and making Prone stand-up cost are explicit decisions. |
| S-236 (V-064) | Grappled condition p. 183; Unarmed Strike Grapple/Shove p. 190 | Grappled condition; Unarmed Strike options; monster "Grappled (escape DC …)" riders | S-168 tether relation and `escape_nonmagical_restraint`, tether end rules | S-168, S-235 | The Grappled condition applies with its source, Speed 0, attack Disadvantage vs others, drag cost, escape action, and ends on Incapacitated/out of reach; Shove pushes 5 ft or knocks Prone. |
| S-237 (V-101) | Actions table p. 10 and each action's glossary entry | Dash, Disengage, Hide, Help, Influence, Ready, Search, Study, Utilize; Dodge completeness | Cunning Action dash/disengage/hide branches, `CombatTurnBudget`, `ReactionTriggers`, `EventResolver` | S-160, S-191, S-188; Search reuses the location-scoped search slice proposed in PR #62 | Every SRD action is reachable as a generic Action with its SRD effect. Feature-granted versions reuse it (Bonus Action cost only). Hide uses DC 15 and location preconditions and yields Invisible; Ready holds a trigger and spends the Reaction. |
| S-238 (V-005, V-073) | Cover p. 180 | Ranged and melee attacks, DEX saves, area targeting | Hex LoS/`Targeting`, `physical_facts_rules` obstruction | S-032, S-190 | Half/¾/Total cover are computed from actual obstruction and applied to AC, DEX saves and targeting. |
| S-239 (V-069) | Climbing/Swimming p. 179/190; Crawling p. 181; Jumping p. 184; Prone stand-up p. 188 | Movement without a climb/swim speed, crawl, stand-up, Long/High Jump | S-179 mode/terrain costs | S-179, S-235 | Fallback double-cost climb and swim, crawl, half-Speed stand-up, and STR-based jump distances are on the production movement path. |

**Already planned (no new row):**
- S-070 and S-071 (V-048): rests, Hit Point Dice and interruption.
- S-160 and S-159 (V-060): Reaction and extra-turn budgets.
- S-181 (V-069): flight and fall descent.
- S-180: phasing and burrowing.
- S-188, S-190 and S-191 (V-073): observer, light and concealment.
- S-226: Death Save and concentration choices.

IDs S-235–S-239 and V-100/V-101 avoid S-227–S-234 and V-098/V-099, which open PRs #62 and #63 propose.

## Recommended next queue

1. **S-235 condition table.** Start with the correctness defects: Poisoned turn damage, auto-fail for stunned, unconscious and petrified saves, Character-target Advantage, Prone, and Unconscious at 0 HP being Prone.
2. **S-071/S-070 Hit Point Dice and rest procedure.** Short Rests currently heal nothing.
3. **S-236 Grappled** on top of the verified S-168 tethers.
4. **S-237 generic actions**, with Hide aligned to S-191.
5. **S-238 cover**, then **S-239 jump, climb and crawl**.
