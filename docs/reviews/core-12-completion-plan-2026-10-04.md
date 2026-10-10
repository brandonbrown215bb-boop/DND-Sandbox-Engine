# Core 12, levels 1–20: completion audit and building-block code plan

> Historical snapshot, not current priority or acceptance. See the
> [documentation map](../README.md) for current authority. Findings, counts,
> gate decisions and execution orders below apply to the dated snapshot;
> reproduce relevant behavior before reopening a defect or reusing a claim.

Reviewed 2026-10-04 against the current uncommitted working tree. No production
code was changed by this audit. HEAD is
`9ed572b40b3dd87409380eb1819d96088a7f9ce3`; SHA-256 of sorted
`relative_path sha256(file)` pairs for `src/`, `data/`, `scenes/` and
`project.godot`, joined by newlines, is
`d252510cc450b8f9b86490d4199367ccf1e934072201b4d86a60156dbf3e8e6c`.

**Repair follow-up:** [core-12-defect-repairs-2026-10-04.md](core-12-defect-repairs-2026-10-04.md)
records the subsequent fixes and gameplay evidence. The findings, ledger, and
chart below describe the original audit snapshot; their percentages have not
been recalculated. Missing spell content and the broader completion plan remain
open after these repairs.

## Completion decision

**None of the twelve classes can presently claim 100% implementation through
level 20.** Fighter has the most complete base combat progression and the only
substantially implemented SRD subclass. Most classes have useful high-level
mechanics, but incomplete choices, spell catalogs, shared rules and verification
prevent complete support. A progression record, helper, button, or passing
inventory assertion is insufficient.

The active roadmap milestone is the **twelve base classes**, with selected
subclasses tracked separately. The wider phrase “100% class implementation”
also needs a complete supported subclass, legal class choices and the spells
those choices can grant. This report keeps those scopes distinct. Artificer,
Mystic, multiclassing, other published subclasses and a new level-20 campaign
are excluded. Crown remains level 1–5; a production-path level-up fixture can
prove levels 6–20 without building a new campaign.

A base class reaches 100% only when every required outcome and choice is
implemented, reachable, safely saved where appropriate, recovered/expired at
the correct boundary, and covered by proportionate production Godot evidence.
Narrative benefits and unsupported exploration systems must either receive a
real supported interaction or remain explicitly incomplete. Documenting an
engine limitation does not turn the affected rule into completed behavior.
If a smaller adapted rules contract is desired later, record that decision and
label its completion separately.

### How to read the chart

These are **implementation checklist estimates**, not percentages of work,
test coverage, official spell coverage or independently certified gameplay.
Each feature family in the ledger below has equal weight: **I = 1**,
**P = 0.5**, **M = 0**. Score = `(I + P/2) / family count`. Scores are rounded
to the nearest whole percent. Repeated ability improvements and numeric
capacity changes are grouped, rather than padding the score with repeated
levels. One partially implemented spell catalog counts as one partial family,
even though completing it may take far more effort than another row.

The denominator includes starting class traits, base features, legal choices
and spell access. It excludes actual subclass features and general origin/
species rules. Subclass selection already has a shared boundary; ten classes
have no production subclass to select. The chart therefore cannot be read as
“Fighter needs only the remaining percentage of development time.” No green
family excuses a partial or missing family at acceptance.

| Class | Base mechanics checklist | Implemented / partial / missing families | SRD subclass |
|---|---:|---|---|
| Barbarian | **78%** | 11 / 9 / 0 (20 total) | Missing |
| Bard | **73%** | 6 / 7 / 0 (13 total) | Missing |
| Cleric | **68%** | 5 / 9 / 0 (14 total) | Missing |
| Druid | **63%** | 5 / 9 / 1 (15 total) | Missing |
| Fighter | **85%** | 9 / 4 / 0 (13 total) | Champion implemented |
| Monk | **68%** | 12 / 10 / 3 (25 total) | Open Hand partial (2/4 named features) |
| Paladin | **76%** | 10 / 9 / 0 (19 total) | Missing |
| Ranger | **69%** | 7 / 11 / 0 (18 total) | Missing |
| Rogue | **61%** | 6 / 10 / 2 (18 total) | Missing |
| Sorcerer | **73%** | 6 / 7 / 0 (13 total) | Missing |
| Warlock | **50%** | 1 / 8 / 1 (10 total) | Missing |
| Wizard | **67%** | 4 / 8 / 0 (12 total) | Missing |

The standalone [completion chart](core-12-completion-chart-2026-10-04.svg)
shows implemented/partial/missing family counts and the same calculated score.

## Current spell access, measured through the real loader

The diagnostic created each core class normally and leveled it through 20.
Counts below use each base class's own loaded list, excluding Bard Magical
Secrets expansion, Paladin Blessed Warrior expansion, Warlock invocation
grants and Mystic Arcanum. They count available records, **not verified full
spell behaviors or confirmed legal membership**.

| Class | Total choices | Cantrips / leveled | Available spell levels | Main completion problem |
|---|---:|---:|---|---|
| Bard | 79 | 11 / 68 | 0, 1, 2, 3, 9 | No base-list choices at levels 4–8; expanded lists inherit their gaps. |
| Cleric | 16 | 5 / 11 | 0–3 | Only 11 leveled choices for 22 prepared spells at level 20. |
| Druid | 19 | 4 / 15 | 0–3 | Only 15 leveled choices for 22 prepared spells; no component metadata in this list. |
| Paladin | 35 | 0 / 35 | 1–3 | Upper half-caster spell levels absent; spell-specific effects remain bounded. |
| Ranger | 3 | 0 / 3 | 1–2 | Fifteen-spell preparation capacity cannot be filled; always-prepared grants further affect ordinary capacity accounting. |
| Sorcerer | 8 | 3 / 5 | 0–3 | Four starting cantrips and six level-20 cantrips cannot be selected; only five leveled choices for 22 prepared spells. |
| Warlock | 9 | 6 / 3 | 0–3 | Only three ordinary leveled choices for 15 prepared spells; Pact spell levels 4–5 absent. |
| Wizard | 29 | 7 / 22 | 0, 1, 2, 3, 5, 9 | Cannot supply 44 leveled book entries or 25 prepared entries; levels 4/6/7/8 absent. |

Warlock separately has one loaded Arcanum candidate at each spell level 6–9.
That is four available records, not complete choice coverage. Only seven of
the eight Sorcerer records declare components. Most other lists have zero or
one component-tagged record. There is substantial shared metadata work before
Beast Spells, Subtle Spell, Counterspell and casting restrictions can be fully
accurate. The older seven-spell Sorcerer status note is already stale.

## Five issues worth fixing first

### 1. Fix now — shared attack/save behavior still uses incorrect feature identity

**What happens:** `CombatAction.resolve_spell` recognizes `evasion` and
`monk_evasion`, while the actual Rogue record owns `rogue_evasion`. A seeded
production-Fireball diagnostic dealt **36 damage to Rogue and 18 to Monk**
on the same failed save. The common Evasion branch also lacks the
Incapacitated restriction. `CombatState` resets Sneak Attack only for an owner
of `sneak_attack`, not `rogue_sneak_attack`; a spent marker therefore survives
later Rogue turns. Its eligibility helper accepts an Incapacitated adjacent
ally and receives no weapon information. Reaction and Light follow-up attacks
do not enter that ordinary Sneak Attack path.

**Why care:** A signature defensive feature fails, damage can disappear after
the first turn, and invalid attacks can receive bonus damage.

**Smallest fix:** Use owned effect capabilities for Evasion. Move Sneak Attack
eligibility and its creature-turn limit into the existing Rogue/shared attack
boundary; call it from ordinary, Light and reaction hits. See B2/B3. The
live Evasion failure and adjacent-ally acceptance were reproduced; the reset
and omitted follow-up paths are direct source findings, not a rendered turn
sequence test.

Sources: `src/combat/combat_action.gd:970`,
`src/combat/combat_state.gd:653`, `:2034`, `:3388`, `:3677`;
`src/characters/character.gd:1339`.

### 2. Fix now — a valid Wizard copying request always fails

**What happens:** `ClassProgression.copy_wizard_spell` tests a spell ID against
`get_spell_list_ids()`, which returns class/list IDs such as `wizard`.
The diagnostic used two real Wizards with spellbooks, a recorded Magic Missile
and sufficient gold. It returned “not a valid Wizard spell level”. Spell
Mastery also has no replacement path after its initial choice.

**Why care:** A visible Wizard operation cannot work, and a permanent early
capstone selection cannot be changed through its rules entitlement.

**Smallest fix:** Query eligible spell records using the existing loader list
API; charge only after validation. Add a saved replacement entitlement to the
existing chooser rather than another Wizard UI. See B6/B7.

Sources: `src/characters/class_progression.gd:236`, `:266`, `:277`;
`src/characters/character.gd:253`; `src/autoload/data_loader.gd:1087`.

### 3. Fix now — Empowered Spell implements a different dice operation

**What happens:** `_apply_empowered_spell` rerolls the entire damage expression
and retains the larger total. It has no individual-die selection or reroll cap.

**Why care:** Its value and behavior change with every larger damage spell;
adding content would spread the error.

**Smallest fix:** Keep damage dice as settled roll details, choose eligible
indices, replace those rolls, and recompute once. Reuse that operation for
similar die manipulation. See B2/B4. Source-confirmed; no dice picker or
separate viewport diagnostic was run for this finding.

Source: `src/combat/combat_action.gd:1345`; existing detailed dice support in
`src/autoload/dice.gd`.

### 4. Fix now — remaining older rules data changes actual character benefits

**What happens:** Barbarian still starts with Heavy armor training and Fighter
gear and grants another Primal Knowledge skill at level 10. Wizard still
declares Light/Medium armor training. Druid's Nature Magician checks the
level-1 Magician choice. These are live state/eligibility decisions, not just
stale descriptions.

**Why care:** Players receive the wrong training or are denied a capstone.
Imported text marked “supported” cannot establish compliance.

**Smallest fix:** Correct the current class records, remove the Druid choice
gate, and define bounded earlier-schema-2 handling before changing granted
choices. Do not silently subtract saved scores, delete owned equipment or
discard acquired choices. See C0/B6.

Sources: `data/core/classes/barbarian.json`,
`data/core/classes/wizard.json`, `src/characters/druid_rules.gd:31`.
The Barbarian progression/training comparison and the Nature Magician gate
were checked against [SRD 5.2.1](https://media.dndbeyond.com/compendium-images/srd/5.2/SRD_CC_v5.2.1.pdf#page=28).

### 5. Fix now — legal training can run out of selectable choices

**What happens:** Spell preparation and book learning ask for more distinct
choices than several loaded lists contain. Wizard book learning requires the
entire pending batch; simply adding a few high-level spells will not prove
all twenty level-ups can complete. Current class-list fallbacks also need a
legality review, rather than assuming every curated ID belongs to that class.

**Why care:** A level-up sheet can remain permanently unfinished, even though
the class grants high-level slots and capstone buttons.

**Smallest fix:** Complete a reviewed spell-membership inventory, share spell
behavior by operation, then verify capacity at every level with real saved
choices. Keep incomplete records unavailable. See B4/B6/B9.

Sources: `src/characters/class_progression.gd:142`, `:205`;
`src/autoload/data_loader.gd:22`, `:1087`; measured inventory above.

## Similarities that should be coded once

Reuse ADR-0006's existing boundaries. The game already has common progression,
saved choices, self-activation, resources, spell slots, typed damage and auras.
Complete their contracts at real repeated needs. A universal rule language,
trigger bus, new service or wholesale CombatState extraction is unnecessary.

| Block | Shared behavior | Main consumers | Existing boundary |
|---|---|---|---|
| B1 — sourced effects and expiry | Condition source, stacking, phase, repeat save, break events | Rage, Inspiration, Stunning/Cunning/Brutal effects, turning, fear, spells | Character conditions/modifiers; CombatAction condition sources; CombatState turn hooks |
| B2 — D20 and dice decisions | Failed-test windows, rerolls, die replacement, damage-after-save eligibility | Inspiration, Stroke, Indomitable, Disciplined Survivor, Tactical Mind, Evasion, Empowered | Dice, Character, BardicInspirationRules, CombatAction, event/combat prompts |
| B3 — settled attack context | Attack eligibility, source mark, creature-turn limits, hit/crit/miss riders | Sneak Attack, Reckless, Smite, Radiant/Divine/Primal riders, masteries, invocations | CombatAction plus existing Rogue/Barbarian/Fighter helpers; CombatState spatial requests |
| B4 — complete casting path | Metadata, costs once per cast, targeting, components, spell effects and exceptions | All eight casters; Metamagic, Intervention, Beast Spells, Wizard capstones | CombatAction, CombatCommand, CombatTurnBudget, CombatState, EventResolver |
| B5 — spatial capabilities | Movement mode, obstruction, perception, cover, forced movement | Roving, Acrobatic Movement, Slow Fall, forms, familiars, mounts, fear, Hide, Blindsight | HexGrid/HexUtils, CombatState paths, AIController, attack/target helpers |
| B6 — saved entitlements | Legal options, prerequisites, replacement, languages, tools, feats | Every class; orders, styles, masteries, spellbooks, invocations, boons | ClassProgression, Character, ClassTraining, DataLoader, SaveManager |
| B7 — game time and rests | Elapsed game time, rites/rituals, effect deadlines, rest recovery/choices | Rage, Inspiration, Wild Shape, Arcane Recovery, copying, Magical Cunning, Contact Patron | GameManager, Character rest methods, events and safe checkpoint DTOs |
| B8 — form/summon ownership | Owner link, derived profile, commands, duration/death/removal, reconstruction | Druid forms/familiar, Paladin steed, Warlock Chain, Wizard familiar | DruidRules/PaladinRules, existing combat entity materialization and saved owner state |
| B9 — spell catalog production | One spell implementation, multiple legal class memberships | All casters; Magical Secrets and Arcanum particularly | data/core/spells, class spell IDs, content manifest, resolver allowlists |

Keep specialized rules narrow: Rage sustain, Relentless Rage, Sneak Attack
eligibility, Cunning Strike dice tradeoffs, Metamagic combinations, Pact binding,
Wild Shape retention rules, Intervention exceptions and Quivering Palm staging
remain explicit rules. They compose shared operations rather than pretending
to be ordinary numeric buffs. A typed common operation can live in an existing
helper until two consumers justify a small dedicated file.

## Detailed code changes and acceptance

### C0 — reconcile production class data before expanding it

1. In the twelve `data/core/classes/*.json` files, compare base traits,
   progression, feature grants and class-list membership with the chosen rules
   source. Remove duplicate/older feature grants from current creation. Correct
   misleading 2014 descriptions and links in records still used by the sheet.
2. In `DataLoader.CURATED_FEATURE_EFFECTS` and `CURATED_SPELL_ACCESS`, remove
   contradictory fallback declarations only after their real production
   replacements exist. Continue explicit manifest collision handling. Do not
   treat effectless reference markers as active support.
3. In `DruidRules.nature_magician_options`, remove the Primal Order gate.
   Keep pool, slot, feature ownership and cooldown validation.
4. Add normal-creation checks for exact armor/weapon/skill grants and selected
   order/style options. Verify the level-10 Barbarian does not acquire an extra
   skill entitlement. Preserve earlier schema-2 saves explicitly; no legacy
   migration, broad item deletion or silent permanent-grant repair.

**Acceptance:** new characters receive precisely the reviewed traits; only
enabled executable features appear; earlier compatible saves remain readable
without replayed permanent bonuses.

### B1 — finish effect ownership and lifecycle

1. Extend the existing sourced-condition representation to Character targets as
   well as monster dictionaries. A grant identifies feature, source actor,
   target, duration/phase and break rule. Combat-local IDs stay transient;
   persistent effects use stable character/content IDs.
2. Add explicit start/end phase ticking to existing turn hooks. Keep “end of
   target's next turn” distinct from “start of source's next turn”. Store the
   affected turn identity when applying an effect; decrementing every condition
   at one generic end-of-turn is insufficient.
3. Make condition queries expose relevant consequences consistently to action
   availability, attacks, saves, movement and AI. Frightened, Blinded, Dazed,
   Incapacitated, Unconscious and Hidden need the same consequences regardless
   of which feature applied them. Preserve aura suppression without deleting
   the underlying grant.
4. Store speed adjustments as source modifiers and derive effective speed.
   Stop restoring a captured old speed that may overwrite another source.
   Support the explicit stacking policy of each operation.
5. Reuse one repeat-save and damage-break entry point for Cunning Strike,
   turning, Abjure Foes and applicable spells; narrow helpers decide their
   exceptional behavior. Connect wall-clock-independent expiry through B7.

**Files:** `character.gd`, `combat_action.gd`, `combat_state.gd`,
`combat_turn_budget.gd`, `ai_controller.gd`, `aura_rules.gd`, existing rules helpers.

**Acceptance:** two owners can apply overlapping conditions without clearing
one another; damage removes only the intended source; incapacitation disables
the relevant passive/action; next-turn effects survive and end at the correct
boundary; cleansing and aura exit behave predictably.

### B2 — unify roll decisions and damage-after-save eligibility

1. Build on existing detailed rolls: include test kind, natural roll, modifiers,
   final total, DC, actor/source and success. Leave exceptional natural-roll
   rules at the attack/death-save boundaries. A modifier must not rerun an
   already-settled attack or respend prior decisions.
2. Use one owner-facing failed-test window across spell saves, concentration,
   death saves, skills, tools and hazards. Existing class helpers provide the
   legal options and costs. Define ordering for reroll, roll replacement and
   added dice explicitly; a cancelled option spends nothing.
3. Check `has_feature_effect("evasion")` plus save/effect eligibility and
   incapacitation, rather than a short list of class IDs. Use the same operation
   for Rogue, Monk, traps, creature abilities and spells.
4. Keep damage as individual roll details until die-changing choices finish.
   Provide bounded selected-die replacement; source-specific rules set eligible
   indices and maximum count. Empowered Spell uses the replacement rolls even
   when the damage becomes lower. Preserve Heroic Inspiration's existing
   ownership and forced-new-roll behavior.
5. Record the settled roll once in ActivityHistory after all legal decisions;
   do not publish a speculative failed result followed by a second attack.

**Files:** `dice.gd`, `character.gd`, `combat_action.gd`, `combat_state.gd`,
`combat_hud.gd`, `event_resolver.gd`, `rogue_rules.gd`,
`bardic_inspiration_rules.gd`, existing activity adapters.

**Acceptance:** production Rogue Fireball damage matches Evasion; incapacitated
Rogue/Monk receive ordinary damage; Empowered changes only selected dice and
can lower the result; accepting/declining roll options charges exactly once;
the Rogue concentration/save prompt reaches the owner's real viewport flow.

### B3 — use one attack context and rider boundary

1. Add a small settled attack context to current resolution: actor, target,
   actual attack ability, weapon properties, attack kind, originating action,
   attacking creature-turn ID, distance and rolled dice. Distinguish Attack
   action attacks, Bonus Action/Light attacks, reaction attacks and spell
   attacks. Derive ability after Finesse/Martial Arts/Pact choices.
2. Place outgoing attack-condition modifiers at the common resolver. Reckless
   Attack must affect every eligible subsequent attack, not just the first
   accepted popup. Track whether the first-roll decision was offered even when
   declined, and apply the same eligible context to thrown/reaction attacks.
3. Move Sneak Attack validation into `RogueRules` using weapon properties,
   Advantage/Disadvantage and an eligible adjacent creature. Bind its once-per-
   turn use to the current creature turn, so an eligible reaction on another
   turn can work. Route normal, Light and opportunity hits through it.
4. Extend the current weapon-rider operation with declared attack eligibility,
   optional choice, source ownership, turn limit and critical-die handling.
   Keep Cunning Strike's tradeoff dedicated; it receives the same settled hit.
   Apply Divine/Primal/Radiant riders and invocation riders consistently.
5. Associate Hunter's Mark bonuses/Advantage with the caster's mark target and
   source, not any creature carrying the condition. Keep transfer, concentration
   and free-cast accounting in the existing spell operation.
6. Return Push/Withdraw/Pounce requests to existing CombatState movement code;
   the resolver does not mutate occupancy or choose UI destinations.

**Files:** `combat_action.gd`, `combat_state.gd`, `rogue_rules.gd`,
`barbarian_rules.gd`, `fighter_rules.gd`, `warlock_rules.gd`, class JSON riders.

**Acceptance:** Sneak Attack works across two owner turns, fails for an invalid
weapon/incapacitated-only ally, and works once on an eligible off-turn hit;
Reckless affects the later eligible roll; two Rangers do not inherit each
other's mark; critical/rider damage is settled once with shared mitigation.

### B4 — finish the common casting contract

1. Give each enabled spell reviewed metadata for legal class/school membership,
   casting time, range kind, target restrictions, sight, shape/area, duration,
   concentration, components, material price/consumption, save/attack and upcast
   behavior. Distinguish Touch from an ordinary five-foot range. Validate fields
   required by the behavior rather than silently guessing from missing data.
2. Prepare a pending cast before mutation. Gather slots/free casts, variants,
   Metamagic and targets; revalidate the current actor/turn/targets; commit
   action, pool and slot costs once. Use a per-cast identity for area/multi-ray
   work so modifiers and Arcane Apotheosis do not respend per target.
3. Track turn-level spell-slot spending at the shared budget for every caster,
   including reaction casts and Smite. Keep Action Surge's restricted action
   and Quickened's extra restrictions explicit. Free casts and created slots
   must have separate accurate policies.
4. Consolidate spell effects currently split between `resolve_spell`,
   `_handle_spell_effects`, area handling and ritual calls. Return settled
   effect/spatial requests rather than applying a save-dependent condition
   unconditionally in a later caller. Add a supported out-of-combat target
   path; rituals currently resolve against the Wizard alone and do not enter
   combat's later effect application.
5. Parameterize eligible protected targets and damage-roll modification so
   Careful Spell, later Sculpt Spells, Potent Cantrip and spell damage bonuses
   can share bounded operations. Complete selected-die Empowered, target-level
   Heightened/ongoing saves, Seeking across supported attacks, multi-payload
   Transmuted and Twinned target metadata. Test allowed option combinations,
   exceptions, and exactly one free option each turn.
6. Finish component availability, focus/hand restrictions and explicit feature
   exceptions. Beast Spells must reject unknown material eligibility rather
   than assume missing metadata is harmless. Subtle and Counterspell use the
   actual components of the pending modified cast.
7. Review Counterspell/Shield and other common reactions against the baseline;
   Counterspell currently interrupts automatically. Implement its proper save
   and slot outcome through B2, with range/perception checks through B5.
8. Reuse this path for Intervention/Wish duplication, free Arcanum, Spell Mastery
   and Signature Spells. Exceptions declare bypassed restrictions; they must
   not reimplement targeting, healing, damage and concentration.

**Files:** `combat_action.gd`, `combat_state.gd`, `combat_command.gd`,
`combat_turn_budget.gd`, `combat_hud.gd`, `event_resolver.gd`,
`sorcerer_rules.gd`, `cleric_rules.gd`, `class_progression.gd`,
`data_loader.gd`, spell JSON/manifest.

**Acceptance:** one-target/area/multi-ray casts charge once; cancelled targeting
charges nothing; hit/save/miss effects are correct; component and free-cast
exceptions hold; ritual effects actually occur; two legal Metamagic options
compose; the waiver is not multiplied by target count.

### B5 — add only the spatial rules these class features require

1. Extend existing tile/path data with traversal capabilities: walk, climb,
   swim and fly. Represent surface/hazard/elevation only where a shipped
   mechanic uses it. One shared path eligibility/cost query feeds players,
   summoned creatures and AI.
2. Add a fall outcome/reaction point, then wire Slow Fall; add surface traversal
   and stop/end-of-turn legality, then wire Acrobatic Movement. Implement the
   Step of the Wind/Heightened willing-creature move using an explicit temporary
   carrier link and shared occupancy updates.
3. Centralize perception/sight, Total Cover and attack cover eligibility in the
   tactical map. Blindsight reuses it. Keep Invisible distinct from an unknown
   location; Hide must establish a valid hidden state and its reveal rules.
4. Apply Frightened movement and attack constraints from B1 to player path
   selection and AI. Daze/Abjure should permit the legal choice of movement or
   action; converting every move-and-attack command to movement is a bounded
   approximation, not complete behavior.
5. Make one clear-space/straight-line forced-movement request operation usable
   by mastery Push, Forceful Blow, Open Hand and spell/invocation pushes.
6. Add steed mounting and paired movement using B8 ownership. Flight must affect
   legal routes/position rather than just display a Fly Speed number. Refresh
   aura/perception context after every ordinary, forced and paired move.

**Files:** `hex_grid.gd`, `hex_utils.gd`, `combat_state.gd`, `ai_controller.gd`,
`combat_action.gd`, `aura_rules.gd`, Druid/Paladin/Monk rules.

**Acceptance:** Roving climb/swim and forms/steeds fly through genuinely
eligible routes; Slow Fall has a real hazard trigger; cover/sight blocks an
otherwise in-range target; carrying/mounting leaves valid occupancy; optional
movement cancellation cannot undo an already-settled feature effect.

### B6 — complete saved choices without replaying permanent grants

1. Extend `ClassProgression`'s current entitlements with an explicit option kind,
   source, count, prerequisites and replacement cadence. Preserve pending
   choices when interrupted. Do not add a second competing training system.
2. Implement a small SRD feat registry using executable common effects and
   narrow handlers. ASI is one qualified choice, not the whole general-feat
   contract. Connect supported Epic Boons to the same saved entitlement;
   enable Monk's disabled level-19 choice only after its outcomes work.
3. Add language and tool-training state and relevant check eligibility. Reuse
   proficiency/Expertise/floor operations for languages, tools, Thieves' Cant,
   Deft Explorer, Druidic, Scholar and initial skill choices. Save authoritative
   acquisition choices; derive membership without adding scores on reload.
4. Finish preparation/replacement/rest entitlements by class. Broad spell-list
   expansion must not imply that every existing spell can be changed at any
   moment. Replace Spell Mastery via its proper entitlement; retain Signature
   Spells' distinct policy. Repair Wizard copying's list-ID comparison.
5. Extend Warlock selections with explicit repeatability/prerequisite checks
   against the new final selection, without requiring abandoned options to
   remain installed. Implement Pact weapon identity/binding instead of granting
   every equipped melee weapon its benefit. Review earlier-edition invocation
   IDs before presenting the subset as SRD compliant.
6. Extend `ClassTraining` and creation's existing controls with readable pending
   choice counts, legal options and unavailable reasons. Avoid offering an
   unfillable all-at-once selector without an explanation.
7. Validate new DTO fields before active managers mutate. Define defaults for
   older schema-2 saves. Keep the 2024 namespace; preserve unrelated equipment,
   scores, spent pools and consumed choices. New fields do not by themselves
   require a new schema; incompatible interpretation requires an explicit
   compatibility decision.

**Files:** `class_progression.gd`, `character.gd`, `class_training.gd`,
`character_creation.gd`, `character_sheet.gd`, `warlock_rules.gd`,
`inventory.gd`, `data_loader.gd`, `save_manager.gd`, class/feat data.

**Acceptance:** complete legal choices at every level, reject wrong prerequisites
and stale replacements, resume pending selections after reload, and never
refill spent resources or replay score grants. Saved illegal/missing required
content rejects preflight with a useful reason.

### B7 — game time and rest-driven operations

1. Add one elapsed **game-time** value to existing campaign state. Advance it
   through tactical rounds, travel/event durations, rests and explicit downtime
   operations; do not use real elapsed computer time or require a background
   timer/service. Save it at ordinary safe checkpoints.
2. Give cross-encounter effects an absolute game-time deadline and stable source
   identity. Keep turn-phase effects in B1. Expire Rage, Inspiration, Wild Shape,
   sense effects and timed spells consistently across scene changes and reload.
3. Move Arcane Recovery to a Short Rest choice with bounded slot-level
   allocation; retain the shared capacity helper and Long Rest cooldown. Offer
   the player's allocation rather than choosing expensive slots automatically
   in combat.
4. Use an explicit elapsed-time action for Magical Cunning, rituals, copying and
   Contact Patron. Validate ownership, resources and allowed context before
   advancing time/committing costs. Show the result on the existing sheet/event
   UI and preserve interruption state when an operation spans checkpoints.
5. Add the small Exhaustion/rest state needed by Tireless and Monk's food/drink
   exception; run recovery in Character's existing Short/Long Rest lifecycle.

**Files:** `game_manager.gd`, `character.gd`, `event_resolver.gd`,
`class_progression.gd`, `class_training.gd`, `combat_state.gd`,
`save_manager.gd`, relevant campaign DTO checks.

**Acceptance:** leaving and reentering combat does not reset durations; reload
does not grant free time/uses; rest options obey their cadence; copying charges
gold and time only after a valid request.

### B8 — reuse entity ownership, retain distinct form/familiar/steed rules

1. Reuse existing owner-saved summon data and combat materialization. Common
   fields are stable owner ID, source feature/spell, entity role, derived
   profile, remaining HP, cooldowns and lifetime. Keep familiar, steed and
   transformed character behaviors distinct.
2. Finish Wild Shape's retained/replaced statistics, saving throw and skill
   proficiency selection, size, equipment decisions, senses, movement, attacks
   and traits. Validate each selectable form against implemented capabilities;
   incomplete Beasts must remain unavailable.
3. Reuse the familiar lifecycle for Druid/Wizard/Warlock. Add explicit owner
   commands and check Help, touch-spell delivery and shared senses. Warlock's
   attack permissions compose with reaction and attack-action budgets; they do
   not make every familiar an ordinary attacking party member.
4. Finish steed rider links, mounted decisions, paired teleport/movement and
   bond interactions. Share owner-death/dismissal/expiry cleanup. Transient
   combat context is recomputed after restore, not saved as Node/instance IDs.

**Files:** `druid_rules.gd`, `paladin_rules.gd`, `warlock_rules.gd`,
`combat_state.gd`, `combat_action.gd`, `character.gd`, `save_manager.gd`,
Beast/familiar/spell data.

**Acceptance:** summons survive intended scene boundaries with exact HP/uses,
remove cleanly on death/dismissal/expiry, and reload without duplication; forms
retain the correct character identity and mental/proficiency benefits.

### B9 — complete spell content by shared operation, not class duplication

1. Make one reviewed list of required SRD spell IDs, class memberships and
   implementation status. Compare imported records with it; descriptive data
   is not executable content. Missing and partial spells stay visible in the
   audit, unavailable in normal pickers.
2. Continue the currently ready Wizard catalog task: close levels 4/6/7/8 and
   supply at least 44 distinct legal leveled choices, including enough legal
   choices at each earlier level. The 22-choice shortfall is a **minimum
   capacity repair**, not complete Wizard spell support.
3. Batch spell implementation by behavior: direct save/attack damage; healing/
   cleansing; timed buffs/conditions; displacement; areas/hazards; summons/
   forms; exploration/information; resurrection and other state changes.
   Parameterize common behavior. A spell used by four classes gets one resolver
   and four legal memberships.
4. For each batch, complete all modeled effects, upcast behavior, components,
   targets, duration and concentration together. Do not promote a spell merely
   because its damage portion works. Encounter/campaign effects needing owner
   adjudication must have an explicit supported interaction, or stay partial.
5. Expand the Warlock invocation/Arcanum spell dependencies and the Bard's
   expanded lists from those same verified spell records. Meet Cleric/Druid/
   Ranger/Sorcerer/Warlock preparation capacities and all upper spell tiers.

**Files:** `data/core/spells/*.json`, class spell IDs, `content_manifest.json`,
`data_loader.gd`, common resolvers, focused spell/viewport checks.

**Acceptance:** no list contains an illegal base grant; every enabled spell
has a reachable complete operation; ordinary class choices can be filled at
every level; cross-class casting of one spell produces the same shared result
except for owned modifiers. Counts are reported separately from behavior proof.

## Subclasses: separate completion work

The milestone's base progress must not silently include subclass features.
The existing registry/selected-subclass DTO already supplies the foundation.
Full SRD class support requires these missing records and verified behavior:

| Class | Subclass | Production state | Reuse / dedicated next work |
|---|---|---|---|
| Barbarian | Path of the Berserker | Missing | B3 hit riders and B1 immunities/fear; narrow subclass triggers. |
| Bard | College of Lore | Missing | B6 proficiency/spell entitlements; B2 optional roll reactions. |
| Cleric | Life Domain | Missing | B4 healing modifiers/always-prepared spells; Channel Divinity target allocation. |
| Druid | Circle of the Land | Missing | B4/B6 spell grants and B7 recovery; area/aura operations. |
| Fighter | Champion | Implemented within documented limits | Retain existing progression/viewport evidence; broader B2/B3 changes must preserve it. |
| Monk | Warrior of the Open Hand | Partial | Open Hand Technique and Quivering Palm unavailable; Wholeness and Fleet Step implemented. |
| Paladin | Oath of Devotion | Missing | B3 weapon modifier, B4 spell grants and B1/aura effects. |
| Ranger | Hunter | Missing | B3 source-aware rider/target facts and shared damage mitigation. |
| Rogue | Thief | Missing | B5 traversal, B6 item/scroll choices and B7 object/magic-item action behavior. |
| Sorcerer | Draconic Sorcery | Missing | B3/B4 modifiers, B5 flight and B8 spell-dependent summon behavior. |
| Warlock | Fiend Patron | Missing | B2 roll bonus, B4 spell grants and B1/B3 mitigation/damage triggers. |
| Wizard | Evoker | Missing | B2 damage manipulation, B4 protected targets/bonuses and B6 book grants. |

For Open Hand, wire a post-Flurry-hit option using B1/B3/B5. Quivering Palm
needs a saved/source-owned delayed mark and a separate legal later trigger;
the existing immediate-damage helper is insufficient. Its exact lifetime,
range/plane constraints, Attack-action interaction and replacement must be
reviewed before enabling the record. Do not count Wholeness/Fleet Step as
Monk base features.

This table inventories the SRD subclass scope; it does not require every
published subclass or authorize a general subclass respec system.
See the [SRD class chapters](https://media.dndbeyond.com/compendium-images/srd/5.2/SRD_CC_v5.2.1.pdf#page=28).

## Delivery order and practical acceptance

This is a recommended plan, not a new accepted architecture decision or a
replacement for `roadmap.md`. The implementation quest's current Wizard next
action is preserved. Proceed in bounded slices:

1. **Repair demonstrated shared mistakes.** C0 corrections; Rogue Evasion and
   Sneak Attack reset/eligibility; Wizard copying. Add small regressions for
   those failures. Correct Empowered before expanding damage spell choices.
2. **Resume the ready Wizard catalog work.** B4/B9, prioritizing missing spell
   levels and a legal complete 1–20 book-learning path. Close basic class
   choice capacity gaps with verified common spell operations.
3. **Finish shared combat contexts.** B1/B2/B3/B4, introduced when the next
   feature needs them. Use Rogue/Monk Evasion and cross-class riders as reuse
   checks; do not rewrite unrelated combat code.
4. **Finish saved choices and rest/time.** B6/B7; the smallest executable feat,
   tool/language and rest-choice slices first. Preserve schema-2 saves and
   pending choices throughout.
5. **Finish spatial/form/summon gaps.** B5/B8 for real Ranger/Monk/Druid/Paladin
   features. Extend the catalog as those capabilities become complete.
6. **Close each base-class ledger in the active roadmap order.** No “all
   classes done” declaration while any P/M family or required choice remains.
   Handle the selected SRD subclasses in a separately named pass.

For every slice: validate real content loading and entitlement, exercise the
player-facing activation/choice, verify exact effect/cost/cancel/recovery and
relevant save behavior, update the mechanics note and ledger. Python may
validate tables/references/counts; Godot owns behavior proof. Avoid duplicating
the game formulas into a Python “implementation” test.

Extend `src/class_feature_checks.gd`, `src/fighter_checks.gd` and existing
viewport scenarios with the meaningful failures above. Add focused scenario
names only for new UI/context contracts, such as a Rogue two-turn/reaction
sequence, dice selection, a Wizard rest/copy operation and movement-mode
behavior. One focused passing run per slice is enough; run the broader logic
and affected integration suite after the shared changes settle. Save-boundary
changes need preflight rejection and one isolated fresh-process reload; every
class does not need a duplicate persistence harness.

Before the final completion claim, use normal creation and all twenty level-ups
for each class with legal choices at each threshold. A progression inventory
probe alone is not that test: the diagnostic for this audit intentionally did
not fill all pending spell/feat choices. Require a reproducible owner path to
each unique mechanic, capstone and important repeated-context behavior.

**Fix when touched:** legacy helper file names and generic operation placement.
**Ignore:** a blanket CombatState rewrite, a universal feature engine, test
coverage percentages, unrelated controller/network/publication work.

## Feature-family ledger through level 20

These rows are the exact denominator of the chart. Repeated ASIs and numeric capacity upgrades are grouped; a new behavioral upgrade has its own row. The codes refer to the code plan above. **I** means a production implementation was located with existing evidence; it is not a fresh full certification. **P** means bounded behavior exists but a required outcome, choice, context or verification is incomplete. **M** means unavailable or ineffective. Each P/M row must close before the base milestone can claim 100%.

### Barbarian

| Level(s) | Requirement family | Status | Evidence / remaining change |
|---|---|:---:|---|
| 1 | Core training and starting equipment | P | C0: Heavy armor training and Fighter starting gear remain in the record. |
| 1 | Rage | P | B1/B3/B7: extension triggers, dedicated extension action, ten-minute ceiling, cross-scene expiry. |
| 1 | Unarmored Defense | I | Shared AC calculation; shield exception is curated at load. |
| 1/4/10 | Weapon Mastery | I | Shared saved capacity and mastery follow-ups; ordinary non-Fighter bypass was repaired. |
| 2 | Danger Sense | I | Shared conditional Dexterity-save Advantage. |
| 2 | Reckless Attack | P | B3: first-roll decision, subsequent Strength attacks and out-of-turn attacks; current prompt is melee-only and the resolver does not read its outgoing Advantage. |
| 3 | Primal Knowledge | P | C0: remove extra level-10 skill entitlement; preserve earlier acquired choices deliberately. |
| 4/8/12/16 | Ability improvement / feat entitlement | P | B6: score increases work; alternative qualified feats remain unavailable. |
| 5 | Extra Attack | I | Shared Attack action swing count. |
| 5 | Fast Movement | I | Shared speed bonus with Heavy armor restriction. |
| 7 | Feral Instinct | I | Shared Initiative Advantage. |
| 7 | Instinctive Pounce | I | Narrow movement prompt wired to Rage activation. |
| 9 | Brutal Strike | P | B3/B5: common attack eligibility and movement requests; review multiple-owner speed restoration. |
| 11 | Relentless Rage | I | Narrow damage-boundary save and rest-reset escalation; Inspiration helper reused. |
| 13 | Improved Brutal Strike options | P | B1/B3: source-owned expiry and consumption across attack/save paths. |
| 15 | Persistent Rage | P | B7: combat timer and Initiative recovery exist; game-time ceiling and out-of-combat behavior incomplete. |
| 17 | Improved Brutal Strike scaling | I | Same dice table and two-effect selection path. |
| 18 | Indomitable Might | I | Shared Strength total floor for checks and saves. |
| 19 | Epic Boon | P | B6: only the supported subset can be selected. |
| 20 | Primal Champion | I | Acquisition-only fixed score grant; shared cap and HP recalculation. |

### Bard

| Level(s) | Requirement family | Status | Evidence / remaining change |
|---|---|:---:|---|
| 1 | Core training and starting equipment | P | C0/B6: initial choices and packages need rules reconciliation. |
| 1-20 | Spellcasting engine and progression | I | Shared ability, slot and capacity tables. |
| 1-20 | Legal complete spell access | P | B4/B9: 79 records; no level 4-8 base-list choices; inventory is not behavior proof. |
| 1/5/10/15 | Bardic Inspiration | P | B2/B7: failed-test opt-in works; held-die expiry and eligibility need explicit ownership/time. |
| 2/9 | Expertise | I | Shared saved skill choices. |
| 2 | Jack of All Trades | I | Common skill-bonus calculation. |
| 4/8/12/16 | Ability improvement / feat entitlement | P | B6: score increases only. |
| 5 | Font of Inspiration | I | Shared rest recovery and slot exchange. |
| 7 | Countercharm | P | B2/B5: reaction path exists; consolidate eligibility, perception and failed-save timing. |
| 10 | Magical Secrets | P | B6/B9: list expansion works; legal replacement entitlements and full expanded catalog need completion. |
| 18 | Superior Inspiration | I | Shared Initiative resource-floor operation. |
| 19 | Epic Boon | P | B6: limited options. |
| 20 | Words of Creation | I | Always-prepared and additional-target declarations plus dedicated Power Word resolution. |

### Cleric

| Level(s) | Requirement family | Status | Evidence / remaining change |
|---|---|:---:|---|
| 1 | Core training and starting equipment | P | C0/B6: initial choices/packages and shield training need reconciliation. |
| 1-20 | Spellcasting engine and progression | I | Shared Wisdom, slots and capacity. |
| 1-20 | Legal complete spell access | P | B4/B9: 16 records, only 11 leveled; cannot fill level-20 preparation. |
| 1 | Divine Order | I | Shared saved choice, training and check/cantrip bonus effects. |
| 2/6/18 | Channel Divinity pool | I | Shared scaling and one-use Short Rest recovery. |
| 2 | Divine Spark | I | Narrow target/mode rule reuses heal/save/damage boundaries. |
| 2 | Turn Undead | P | B1/B5: source and break-on-damage handling exist; full condition/perception behavior incomplete. |
| 4/8/12/16 | Ability improvement / feat entitlement | P | B6: score increases only. |
| 5 | Sear Undead | I | Shared damage settlement preserves the turning source. |
| 7 | Blessed Strikes | P | B3: damage choice works; turn identity and reaction-hit application need completion. |
| 10 | Divine Intervention | P | B4/B7/B9: curated selection and free cast exist; component/casting-context exceptions and noncombat effects incomplete. |
| 14 | Improved Blessed Strikes | P | B4: temporary HP is currently granted only to the caster, without the beneficiary selection path. |
| 19 | Epic Boon | P | B6: limited options. |
| 20 | Greater Divine Intervention | P | B4/B7/B9: duplication and cooldown exist; full Wish outcomes and eligible catalog incomplete. |

### Druid

| Level(s) | Requirement family | Status | Evidence / remaining change |
|---|---|:---:|---|
| 1 | Core training and starting equipment | P | C0/B6: packages, proficiencies and pending initial skills. |
| 1-20 | Spellcasting engine and progression | I | Shared Wisdom, slots and capacity. |
| 1-20 | Legal complete spell access | P | B4/B9: 19 records, only 15 leveled; metadata and high-level choices absent. |
| 1 | Druidic | M | B6/B7: disabled; language and exploration benefit have no production contract. |
| 1 | Primal Order | I | Shared choice, training and bonus effects. |
| 2/4/8 | Wild Shape and known forms | P | B5/B7/B8: saved forms/physical stats/attacks work; size, equipment, traits, save proficiencies, movement modes and expiry incomplete. |
| 2 | Wild Companion | P | B4/B5/B8: initiative/move/Dodge/attack Help exist; senses, touch delivery, other Help and lifecycle incomplete. |
| 4/8/12/16 | Ability improvement / feat entitlement | P | B6: score increases only. |
| 5 | Wild Resurgence | I | Existing narrow exchange with shared pools and cooldowns. |
| 7 | Elemental Fury | P | B3/B4: choices exist; hit context, critical damage and reaction paths need one shared rider contract. |
| 15 | Improved Elemental Fury | I | Shared level scaling and cantrip range bonus. |
| 18 | Beast Spells | P | B4: missing material metadata permits unknown eligibility. |
| 19 | Epic Boon | P | B6: limited options. |
| 20 | Archdruid Initiative recovery | I | Shared resource-floor operation. |
| 20 | Nature Magician and longevity | P | C0/B7: conversion is incorrectly gated by the level-1 Magician choice; time/aging not represented. |

### Fighter

| Level(s) | Requirement family | Status | Evidence / remaining change |
|---|---|:---:|---|
| 1 | Core training and starting equipment | P | C0/B6: alternate starting packages absent. |
| 1 | Fighting Style | I | Four SRD styles, saved choice and replacement path. |
| 1/4/10/16 | Weapon Mastery | I | Saved choices and eight mastery effects; normal and reaction follow-ups have existing integration evidence. |
| 1/4/10 | Second Wind | I | Common executor, exact costs and scaling/recovery. |
| 2/17 | Action Surge | I | Restricted non-Magic action; one activation per turn. |
| 2 | Tactical Mind | P | B2: implemented for event skill checks; shared ability/tool check coverage still needed. |
| 4/6/8/12/14/16 | Ability improvement / feat entitlement | P | B6: score increases only. |
| 5/11/20 | Extra Attack progression | I | Two/three/four attacks per Attack action. |
| 5 | Tactical Shift | I | Optional movement and cancellation wired. |
| 9/13/17 | Indomitable | I | Failed-save reroll, level bonus, scaling and death saves. |
| 9 | Tactical Master | I | Saved mastery override consumed by common mastery path. |
| 13 | Studied Attacks | I | Transient target identity and next-attack Advantage. |
| 19 | Epic Boon | P | B6: supported subset only. |

### Monk

| Level(s) | Requirement family | Status | Evidence / remaining change |
|---|---|:---:|---|
| 1 | Core training and starting equipment | P | C0/B6: supported package exists; alternate package/initial choices incomplete. |
| 1 | Martial Arts | P | B3: strikes and dice/ability scaling exist; full Unarmed Strike modes/eligibility need completion. |
| 1 | Unarmored Defense | I | Common equipment-aware AC calculation. |
| 2 | Monk's Focus | I | Saved level-scaled shared pool and rest recovery. |
| 2 | Flurry of Blows | I | Production sequence and exact Focus/Bonus Action costs. |
| 2 | Patient Defense | I | Free/paid variants; Heightened temporary HP. |
| 2 | Step of the Wind | P | B5/B8: free/paid movement works; jumping and carrying incomplete. |
| 2-18 | Unarmored Movement | I | Shared level table and equipment restriction. |
| 2 | Uncanny Metabolism | I | Initiative opt-in recovery/heal and Long Rest cooldown. |
| 3 | Deflect Attacks | P | B2/B3/B5: reduction/redirect exists; common attack/visibility/damage packet eligibility needs full coverage. |
| 4/8/12/16 | Ability improvement / feat entitlement | P | B6: score increases only. |
| 4 | Slow Fall | M | B5: disabled; no fall event or reaction window. |
| 5 | Extra Attack | I | Shared swing budget. |
| 5 | Stunning Strike | I | Hit prompt, Focus, success/failure outcomes and source-bound expiry. |
| 6 | Empowered Strikes | P | B3: damage type is currently forced; expose the eligible type choice. |
| 7 | Evasion | P | B2: damage branch works, but shared eligibility must suppress it while Incapacitated. |
| 9 | Acrobatic Movement | M | B5: disabled; traversal surfaces absent. |
| 10 | Heightened Focus | P | B5/B8: extra Flurry strike and Defense HP work; willing-creature movement absent. |
| 10 | Self-Restoration | P | B6/B7: condition removal exists; hunger/thirst Exhaustion exception absent. |
| 13 | Deflect Energy | I | Existing Deflect type eligibility expands. |
| 14 | Disciplined Survivor | P | B2: save proficiency/reroll exist; unify failed-test windows across hazard, spell, concentration and death paths. |
| 15 | Perfect Focus | I | Initiative resource floor, still a narrow existing helper. |
| 18 | Superior Defense | I | Focus cost and typed resistance; incapacitation cleanup exists. |
| 19 | Epic Boon | M | B6: disabled; wire the common saved-choice operation. |
| 20 | Body and Mind | I | Acquisition-only fixed scores; exact saved-score regressions already exist. |

### Paladin

| Level(s) | Requirement family | Status | Evidence / remaining change |
|---|---|:---:|---|
| 1 | Core training and starting equipment | P | C0/B6: initial skill and equipment alternatives. |
| 1-20 | Spellcasting engine and progression | I | Shared Charisma, half-caster slots and capacity. |
| 1-20 | Legal complete spell access | P | B4/B9: 35 records, all levels 1-3; upper half-caster spell levels absent. |
| 1 | Lay on Hands | I | Pool-scaled Bonus Action heal/Poisoned removal. |
| 1 | Weapon Mastery | I | Shared saved choices and mastery behavior. |
| 2 | Fighting Style | I | Common styles plus Blessed Warrior capacity/list effects. |
| 2 | Paladin's Smite | P | B3/B4: hit-triggered spell works; centralize attack context and one-slot-per-turn interaction. |
| 3/11 | Channel Divinity pool | I | Shared capacity and recovery. |
| 3 | Divine Sense | P | B5/B7: combat creature scan works; exploration and place/object sensing absent. |
| 4/8/12/16 | Ability improvement / feat entitlement | P | B6: score increases only. |
| 5 | Extra Attack | I | Shared Attack action budget. |
| 5 | Faithful Steed | P | B5/B8: saved summon/actions/bond work; mounted and flying movement incomplete. |
| 6 | Aura of Protection | I | Shared position refresh and strongest nonstacking save bonus. |
| 9 | Abjure Foes | P | B1/B5: target/save/expiry work; full Frightened behavior and action-or-movement choice incomplete. |
| 10 | Aura of Courage | I | Shared condition suppression with reentry/exit behavior. |
| 11 | Radiant Strikes | P | B3: normal melee weapon rider works; full eligible hit/reaction coverage remains to prove. |
| 14 | Restoring Touch | I | Shared Lay on Hands condition selection and pool costs. |
| 18 | Aura Expansion | I | Same aura radius effect. |
| 19 | Epic Boon | P | B6: limited options. |

### Ranger

| Level(s) | Requirement family | Status | Evidence / remaining change |
|---|---|:---:|---|
| 1 | Core training and starting equipment | P | C0/B6: initial skills/packages need completion. |
| 1-20 | Spellcasting engine and progression | I | Shared Wisdom, half-caster slots and capacity. |
| 1-20 | Legal complete spell access | P | B4/B9: three choices; class-list legality and preparation capacity need repair. |
| 1/5/9/13/17 | Favored Enemy / Hunter's Mark | P | B3/B4/B7: free casts and concentration work; mark-source eligibility, transfer and damage packets need completion. |
| 1 | Weapon Mastery | I | Shared choices and follow-ups. |
| 2 | Deft Explorer | P | B6: Expertise works; languages absent. |
| 2 | Fighting Style | P | B6/B9: saved four styles work; full allowed choice set and casting-style options incomplete. |
| 4/8/12/16 | Ability improvement / feat entitlement | P | B6: score increases only. |
| 5 | Extra Attack | I | Shared swing budget. |
| 6 | Roving | P | B5: walk bonus exists; climb and swim speeds absent. |
| 9 | Expertise | I | Shared saved skill choices. |
| 10 | Tireless | P | B6/B7: temporary HP works; Short Rest Exhaustion reduction absent. |
| 13 | Relentless Hunter | I | Spell-specific damage concentration protection. |
| 14 | Nature's Veil | I | Bonus Action/use cost and two-turn Invisible attack interactions verified in a focused viewport path. |
| 17 | Precise Hunter | P | B3: checks the target's condition, not this Ranger's mark ownership. |
| 18 | Feral Senses | P | B5: invisible-target perception works; general sight/cover behavior absent. |
| 19 | Epic Boon | P | B6: limited options. |
| 20 | Foe Slayer | I | Shared spell-specific damage die override. |

### Rogue

| Level(s) | Requirement family | Status | Evidence / remaining change |
|---|---|:---:|---|
| 1 | Core training and starting equipment | P | C0/B6: weapon proficiency is too broad; tools and packages incomplete. |
| 1/6 | Expertise | I | Shared saved skill choices. |
| 1-19 | Sneak Attack | P | B3: wrong reset ID; no weapon predicate; incapacitated adjacent ally accepted; absent from reaction/Light follow-ups. |
| 1 | Thieves' Cant | M | B6: disabled; language state absent. |
| 1 | Weapon Mastery | I | Shared saved choices and non-Fighter follow-ups. |
| 2 | Cunning Action | P | B1/B5: Bonus Action budget works; Hide needs real cover/perception eligibility. |
| 3 | Steady Aim | P | B3: movement lock and next weapon attack work; spell attacks do not consume/use it. |
| 4/8/10/12/16 | Ability improvement / feat entitlement | P | B6: score increases only. |
| 5 | Cunning Strike | P | B1/B3/B5: cost/options work; route through all Sneak Attack hit contexts and exact movement/effect timing. |
| 5 | Uncanny Dodge | I | Reaction attack-damage halving path. |
| 7 | Evasion | M | B2: live Rogue feature ID is not recognized by damage resolver; diagnostic reproduced full damage. |
| 7 | Reliable Talent | P | B2/B6: skill floor exists; proficient tool/other ability-check eligibility incomplete. |
| 11 | Improved Cunning Strike | I | Same chooser allows two distinct affordable effects. |
| 14 | Devious Strikes | P | B1: save/die costs and monster repeat saves exist; full condition actions and exact phase expiry need consolidation. |
| 15 | Slippery Mind | I | Shared save proficiency effect. |
| 18 | Elusive | I | Incoming attack Advantage cancellation. |
| 19 | Epic Boon | P | B6: limited options. |
| 20 | Stroke of Luck | P | B2: several test paths implemented; concentration prompt and owner-facing save flows still need viewport proof. |

### Sorcerer

| Level(s) | Requirement family | Status | Evidence / remaining change |
|---|---|:---:|---|
| 1 | Core training and starting equipment | P | C0/B6: skill/equipment choices incomplete. |
| 1-20 | Spellcasting engine and progression | I | Shared Charisma, slots and capacity. |
| 1-20 | Legal complete spell access | P | B4/B9: eight choices (three cantrips/five leveled); even initial cantrip capacity cannot be filled. |
| 1 | Innate Sorcery | I | Common activation, timed condition, attack/DC modifier and saved use pool. |
| 2 | Font of Magic | I | Combat and sheet conversion paths; created slots expire on Long Rest. |
| 2-20 | Sorcery Points | I | Saved scaled pool and bounded recovery. |
| 2 | Metamagic effects | P | B2/B4: all ten names have paths; Empowered rerolls whole damage and keeps the higher total; single-target/multi-roll/ongoing effects limited. |
| 4/8/12/16 | Ability improvement / feat entitlement | P | B6: score increases only. |
| 5 | Sorcerous Restoration | I | Shared Short Rest bounded recovery plus Long Rest cooldown. |
| 7 | Sorcery Incarnate | P | B4: reactivation works; consistent option composition/exception limits need full cast coverage. |
| 10/17 | Metamagic choice capacity | I | Saved capacity and level-up replacement checks. |
| 19 | Epic Boon | P | B6: limited options. |
| 20 | Arcane Apotheosis | P | B4: waiver marker exists; prove exactly one option free across area, ray and repeat resolutions. |

### Warlock

| Level(s) | Requirement family | Status | Evidence / remaining change |
|---|---|:---:|---|
| 1 | Core training and starting equipment | P | C0/B6: initial choices/packages incomplete. |
| 1-20 | Pact Magic engine and progression | I | Saved slots, slot-level table and Short Rest recovery. |
| 1-20 | Legal complete spell access | P | B4/B9: nine ordinary choices, only three leveled; reconcile curated lists with the rules baseline. |
| 1-18 | Eldritch Invocations | P | B3/B4/B6/B8/B9: saved choice/prerequisites exist; seven-option subset, binding and many effects incomplete. |
| 2 | Magical Cunning | P | B7: recovery amount works; rite time missing. |
| 4/8/12/16 | Ability improvement / feat entitlement | P | B6: score increases only. |
| 9 | Contact Patron | M | B4/B7/B9: disabled; spell and automatic-success exception unavailable. |
| 11/13/15/17 | Mystic Arcanum | P | B4/B6/B9: one free spell per level and replacement exist; one candidate per tier, eligible list incomplete. |
| 19 | Epic Boon | P | B6: limited options. |
| 20 | Eldritch Master | P | B7: Magical Cunning's table restores all slots; rite and feature visibility need completion. |

### Wizard

| Level(s) | Requirement family | Status | Evidence / remaining change |
|---|---|:---:|---|
| 1 | Core training and starting equipment | P | C0/B6: armor training remains light/medium; packages and equipment validation incomplete. |
| 1-20 | Spellcasting engine and progression | I | Shared Intelligence, slots and capacity. |
| 1-20 | Legal complete spell access | P | B4/B9: 29 choices/22 leveled; 44 learned spells cannot be supplied; no levels 4/6/7/8. |
| 1-20 | Spellbook learning and copying | P | B6/B7: learning is saved; copying compares spell IDs with class-list IDs and always rejects a normal legal spell. |
| 1 | Ritual Adept | P | B4/B7/B8: visible no-slot entry exists; exploration effects, time and target handling incomplete. |
| 1 | Arcane Recovery | P | B6/B7: bounded allocation exists; production exposes combat use instead of a Short Rest allocation choice. |
| 2 | Scholar | I | Shared restricted Expertise choice. |
| 4/8/12/16 | Ability improvement / feat entitlement | P | B6: score increases only. |
| 5 | Memorize Spell | I | Saved Short Rest replacement entitlement. |
| 18 | Spell Mastery | P | B6: free versus slot cast works; chooser prevents replacing already-selected mastery choices. |
| 19 | Epic Boon | P | B6: Spell Recall only. |
| 20 | Signature Spells | I | Saved distinct choices, per-spell free casts, Short Rest recovery and reaction cast mode. |


## Evidence and limitations

Read current operations, architecture, active roadmap and ADR-0004/0005/0006;
all class/subclass records, mechanics notes, shared-rule review and relevant
production loader/progression/character/combat/choice/save/test paths. Older
mechanics and architecture paragraphs disagree with current Wizard, Rogue,
Sorcerer and Warlock source; this assessment prioritizes current source.

One Godot 4.7 headless diagnostic used the real project loader and normal
Character initialization/level-ups, reported **zero content validation
failures**, and ended with `CORE12_COMPLETION_AUDIT_COMPLETE`, with no script
errors. It measured catalogs/subclasses and reproduced Rogue Evasion,
Incapacitated-ally Sneak Attack acceptance and Wizard copying rejection.
Evasion used a synthetic guaranteed-failure caster score and a seeded
production Fireball to compare the actual resolver branch; it was not a
rendered combat playthrough. The reset marker gate was observed directly;
no live two-turn sequence was claimed.

Disposable probe, inventory, scores and logs are under ignored
`.artifacts/core12-completion-audit/`. APPDATA/LOCALAPPDATA were isolated inside
that directory; no real saves were read or changed. Existing full-suite results
in `docs/operations/current.md` are historical evidence, not a new test result
for this report. No full suite, full SRD spell behavior audit, fresh-process
save proof or independent reviewer was run. Team contracts, CodeGraph command
and Agent Ground command were unavailable; GDScript source inspection remained
available. The individual I/P scores are transparent audit judgments, not
automatically inferred from `rules_status` or assertion counts.

This work includes material from the System Reference Document 5.2.1
(“SRD 5.2.1”) by Wizards of the Coast LLC, available at
https://www.dndbeyond.com/srd. The SRD 5.2.1 is licensed under the Creative
Commons Attribution 4.0 International License, available at
https://creativecommons.org/licenses/by/4.0/legalcode.
