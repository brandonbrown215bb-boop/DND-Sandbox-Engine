# ADR-0019: Shared ordered execution contract and data-driven zero-HP replacement

Date: 2026-10-10
Status: Accepted (Corrections A3, B1, B1R1, B1R2, Stage B2A normal-controls proof, and Stage B2B fresh-relaunch recovery verified)

## Context

[ADR-0018](0018-shared-data-driven-rules-runtime.md) established the architecture direction for one shared data-driven rules runtime. [ADR-0017](0017-shared-json-spell-execution.md) required shared JSON spell execution to support mixed checks and ordered step composition without monolithic native handlers.

To validate the core data-driven runtime with production evidence before broad migration, Phase 1 of the roadmap required implementing the smallest typed, shared, ordered-execution contract through the production pipeline for both spells and creature rules:
1. Ordered spell execution supporting mixed attack and saving-throw steps, independent area outcomes, conditional gates, and awaited suspension/resume.
2. Data-driven zero-HP replacement governing creature resilience without feature-ID dispatch, demonstrated by Zombie Undead Fortitude under SRD 5.2.1 ([SRD 5.2.1 PDF p. 343](https://media.dndbeyond.com/compendium-images/srd/5.2/SRD_CC_v5.2.1.pdf)).
3. Strict persistence compatibility and separate-process relaunch verification.

## Decision

### 1. Unified Shared Step Executor (`SharedStepExecutor`)

A single, cohesive ordered execution runtime (`SharedStepExecutor`) owns step iteration, conditional gating, target resolution, and result collection for both spells and creature event rules:

- **Single Execution Owner**: Replaces parallel or separate rule interpreters. Spells (`SharedSpell`) and creature damage events (`CombatAction`) delegate execution to `SharedStepExecutor`.
- **Adapters & Capability Contexts**: `SpellAdapter` supplies spell context, targeting, attack/save/damage world calls, and suspension continuations. `DamageEventAdapter` supplies event facts, actor saving throws, and final HP replacement commits.
- **Preflight Capability Refusal**: The executor validates adapter capability before any step execution, actor mutation, or resource deduction. Steps with unsupported types, fields, or target modes for the host context (`"spell"` vs `"zero_hp_replacement"`) trigger immediate preflight refusal (`refused: true`). Spells disallow `replace_hp` and event-only save fields (`dc_base`, `dc_add_damage`, `save_ability`). Zero-HP replacement rules disallow `attack`, `damage`, `effect`, and `self`/`area` targets.
- **Strict Scalar Validation**: Rule and step fields (`type`, `trigger`, `id`, `gate_step`) must be explicitly scalar `String` (or integer index where supported); boolean or loose value coercion into string types is strictly forbidden.
- **Step Structure**: Steps specify `id` (string), `type` (`attack`, `save`, `damage`, `effect`, `replace_hp`), and `target` (`target`, `area`, `self`).
- **Conditional Gating**: Steps may specify `gate` (`always`, `hit`, `miss`, `failed_save`, `successful_save`) and `gate_step` (referencing an earlier step by name or relative index). Steps failing their gate condition are skipped with explicit status, preserving prior outcomes.
- **Ordered Results**: Resolving steps yields top-level summary results (`hit`, `saved`, `replaced`, `damage`, `effect_cast`) and an array of `step_results`, each containing `step_id`, `type`, `target_mode`, `hit`, `saved`, `replaced`, `damage`, and detailed `target_outcomes`.
- **Area Targeting & Scope**: Area steps resolve independently across all area targets. Area damage rolls are scoped per step via `spell_damage_context` so area targets share the single damage roll while non-area steps roll independently.
- **Preserved Damage**: An attack step followed by a gated save step retains the initial attack damage even when the secondary saving throw succeeds.
- **Save Enabling Attack**: A failed initial save enables subsequent attack delivery and damage payload (satisfying ADR-0017).
- **Suspension and Awaited Decision**: Awaited decisions (such as Empowered Spell reroll prompts) suspend at the damage roll boundary with completed steps recorded in an `ordered_continuation` record. Costs (spell slots, actions) commit exactly once prior to suspension; Sorcery Points commit only when rerolls are accepted. Reroll cancellation retains original rolled damage without refunding the cast. Authoritative transient request validation refuses duplicate, copied, stale, or cross-cast callbacks before state mutation; legitimate unconsumed requests remain available.

### 2. Authoritative JSON Creature Ownership and Zero-HP Replacement

Creature drop-to-zero replacement behavior is authored in authoritative JSON and executed via `SharedStepExecutor`:

- **Authoritative JSON**: Creature abilities live in JSON (`core_monsters.json`, `dread_husk.json`). Abilities declare `type: "zero_hp_replacement"`, `trigger: "zero_hp"`, and explicit `steps` (`save` followed by gated `replace_hp`).
- **Projections**: `CreatedCreatureRules` copies special abilities directly from `DataLoader.get_monster(form_id)` into both Character `features` and monster `special_abilities`. No hardcoded feature policy exists in native creature construction.
- **Typed Validation**: `DataLoader` validates monster special abilities at load time. Runtime queries validate rule shape and reject malformed rules before any state mutation occurs.
- **Competing Replacements**: If multiple replacement rules exist on a single target, the runtime refuses execution with a diagnostic warning rather than arbitrarily selecting the first rule.
- **Timing at Drop-to-Zero Boundary**: Evaluated directly inside `Character.take_damage` and `CombatAction.resolve_damage` at the exact boundary when `current_hp <= 0`, before irreversible death or incapacitation bookkeeping (`end_rage()`, `DruidRules.revert_for_incapacitation()`, `CorpseRules.mark_dead()`, `body_death_serial += 1`). A successful replacement commits before these transitions occur, preserving raging states and identity. Failed or bypassed replacements proceed to normal settlement once.
- **Downed Damage & Temporary HP Accounting**: When an already-downed actor (`current_hp <= 0`) takes damage, Temporary HP absorbs damage first without causing death save failures. Leftover damage penetrating the buffer to 0 HP causes instant death if it equals or exceeds `max_hp` (`CorpseRules.mark_dead(self, "massive_damage")`). Otherwise, it inflicts one death saving throw failure (two on critical hits), marking death if failures reach three. An already-downed actor never receives zero-HP replacement.
- **Bounded Replacement HP**: Replacement HP is bounded by the target actor's `max_hp` before commit (`mini(replacement_hp, max_hp)`), ensuring replacement never leaves `current_hp > max_hp`. Dead actors cannot be resurrected by replacement, and `corpse_state.clear()` is eliminated from replacement commit.
- **Legacy Helper Neutralization**: `CreatedCreatureRules.resolve_fortitude` is deprecated and neutralized (`return false`), eliminating parallel native execution. Legacy `undead_fortitude` boolean flags map to the data-driven definition.
- **Policy Follows Data**: Verified using an independently named homebrew creature (`sandbox:dread_husk` with `inexorable_resilience`) that executes identical replacement behavior purely from JSON data without native registration.

### 3. Source Clause Ledger: Zombie Undead Fortitude (SRD 5.2.1 p. 343)

Official source link: [D&D 5.2.1 System Reference Document p. 343](https://media.dndbeyond.com/compendium-images/srd/5.2/SRD_CC_v5.2.1.pdf).

| Source Clause (SRD 5.2.1 p. 343) | Engine Interpretation / Contract | Verified Status |
|---|---|---|
| "If damage reduces the zombie to 0 hit points..." | Triggered in `CombatAction.resolve_damage` and `Character.take_damage` when `current_hp <= 0` and `hp_before > 0` before death settlement. | Verified (exact-zero & lethal damage) |
| "...it must make a Constitution saving throw with a DC of 5 + the damage taken..." | `dc = dc_base + damage`; DC = 5 + resolved damage taken. Target rolls CON save. | Verified (DC 5 + damage formula) |
| "...unless the damage is radiant..." | Radiant damage bypasses replacement: `bypass_damage_types: ["radiant"]`. | Verified (radiant lethal damage causes death) |
| "...or from a critical hit." | Critical hit bypasses replacement: `bypass_critical: true`. | Verified (critical hit bypasses replacement) |
| "On a success, the zombie drops to 1 hit point instead." | Successful save sets `current_hp = 1`, `is_alive = true`, clears death failures before corpse creation. | Verified (leaves 1 HP on success) |
| Exclusions strictly radiant & critical | No massive damage bypass assumption is applied. Overkill damage with a successful save triggers replacement to 1 HP. Overkill with failed save destroys creature. | Verified with deterministic tests |
| Retained stat differences | Authoritative JSON defines `undead_fortitude` with steps. Core monster has `hit_points: "3d8 + 9"` and Slam `1d6 + 1`; created creature retains balance HP `15` and Slam `1d8`. Both project the same JSON replacement trait. No broader stat-block conversion or whole Zombie support is claimed. | Verified in `core_monsters.json` & created rules |

### 4. Persistence & Safety Constraints

- **Transient Continuations**: Mid-action suspension continuations (`ordered_continuation`) are transient memory state; saving during active combat action resolution is blocked by safe-checkpoint rules.
- **Source-Owned Timed Grants**: Source-owned timed condition grants created by ordered spell steps (`grant_condition`, remaining seconds, caster identity, spell effect records) serialize into existing schema 2 saves (`user://saves/dnd2024`).
- **Separate-Process Recovery**: Verified via `scripts/validate_ordered_grant_fresh_relaunch.ps1` and `res://scenes/ordered_grant_fresh_relaunch.tscn`. The probe verifies safe-checkpoint recovery across fresh separate Godot processes and asserts load refusal for malformed save fixtures before session replacement.
- **Test Artifact Isolation**: Disposable profiles and test logs are restricted to `.artifacts/tests/` and never alter standard player directories.

### 5. Correction B1: Actor Outcomes, Legal Target Geometry, Exact Continuation, and Per-Actor Settlement

- **Downed Damage & Temporary HP Accounting**: Aligned with SRD 5.2.1 printed p. 18 and Sage Advice Compendium lines 732–735. Temporary HP absorption mitigates damage but does not prevent taking damage. Taking damage at 0 HP inflicts death saving throw failure(s) (2 on critical hits) and massive damage instant death if incoming damage equals or exceeds maximum HP. Full temporary HP absorption is not immunity. Genuine zero damage / immunity causes no failure.
- **Per-Target Gating & Outcomes**: Step prerequisites evaluate per-actor using explicit actor identity (`_same_actor`) across `target_outcomes`. Gating is order-independent across target lists. The visible summary correctly reports attack hit (`hit=true`) even when preceded by non-attack steps. Preflight capability checks strictly refuse unsupported fields/modes before cost or state mutation.
- **Legal Area Discovery & Obstruction**: Sphere, cone, and cube step targeting filters grid tiles by line-of-sight obstruction using `tile.custom_properties["blocks_sight"]`. Downed living actors are eligible area targets. Area steps without encounter spatial context refuse preflight before mutation. A single raw area roll is shared across simultaneous targets while save scaling applies individually.
- **Exact Continuation & Choice Ownership**: Continuations resume from the exact `target_index` and `pending_target` within the same step, iterating remaining area targets without dropping them. Secondary actor damage resolves on `actual_target = ordered_cont.get("pending_target", target)` rather than being redirected to clicked primary targets. Suspended failed-save condition grants apply once after damage settlement using original source and decisions.
- **Authoritative Request Ownership & State Preservation (B1R1)**: Owned pending damage requests are validated authoritatively before state mutation; duplicate, copied, stale, or cross-cast callbacks refuse explicitly before mutation, leaving legitimate requests available. Live Dictionary monster actors retain live canonical references without deep-copy detachment. Encounter grid/participants and raw area rolls are preserved across resume. Root independently reviewed and accepted R1 bounded ownership (`correction-b1r1-acceptance.md`).
- **Per-Actor Settlement in `SpellCastResults`**: `_resolve_stepped_spell_cast` runs stepped spells once rather than re-running the entire program per outer target hex. `_settle_stepped_spell_actors` settles each affected actor once for damage, temporary HP, concentration CON saves (`SpellEncounterLifecycle._check_concentration_save`), turning clearance, and enemy defeat triggers/cleanup.
- **Empowered Spell Multi-Roll Budget**: 1 Sorcery Point commits once per cast across multiple rolls; remaining dice allowance is tracked across legitimate later rolls up to Charisma modifier dice. Cancelled rerolls retain original damage and spend 0 SP.

### 6. Correction B1R2: Damage Packet Facts, Per-Occurrence Settlement, Defeat Transitions, and Pre-Payment Refusal

- **Typed Damage Packet Facts**: `CombatAction.resolve_damage`, `SpellDamageRolls._finish_spell_damage`, and `SharedStepExecutor` carry typed per-actor facts (`damage`, `hp_loss`, `resolved`, `temp_hp_absorbed`, `hp_before`, `hp_after`, `temp_hp_before`, `temp_hp_after`, `is_alive_before`, `is_alive_after`, `critical`, `damage_is_critical`) from the initial damage boundary through ordered results and resumption without resolving damage twice or attributing aggregate area damage to primary actors.
- **Per-Occurrence Settlement**: Damage occurrences settle taking-damage, concentration, and defeat in declared occurrence order. A concentrating actor failing a concentration check drops concentration effects immediately, exposing reduced defenses to subsequent steps in the same cast. Concentrating actors absorbing damage into Temporary HP still roll concentration saves (DC capped at 30 per SRD 5.2.1); zero damage or immunity requires no save; dead or incapacitated actors end concentration immediately.
- **Defeat Settlement & Critical Scoping**: Natural Dictionary monsters marked `is_alive=false` during lethal damage are removed from initiative with defeat callbacks firing exactly once (guarded against duplicate execution). Critical spell attacks that reduce a Zombie or renamed JSON creature (`dread_husk`) to 0 HP strictly refuse `bypass_critical` replacement, while downed Characters take two death save failures. Attack critical metadata is scoped strictly to the attack packet and does not leak to subsequent steps.
- **Pre-Payment Capability Refusal**: Spells requiring unavailable runtime host capabilities (such as area steps lacking encounter spatial context) refuse execution before slot deduction, Sorcery Point expenditure, or source condition consumption (Sanctuary, Invisibility), preserving resources and legal pending state.

### 7. Stage B2A & Stage B2B: Normal-Controls Proof Closure and Two-Process Fresh-Relaunch Recovery

- **Stage B2A Normal-Controls Closure**: `test_shared_spell_normal_controls_flow` (`src/viewport_harness.gd`) verifies multi-step Empowered rerolls across both steps (surfacing remaining `max_dice` in the Step 2 HUD prompt), live two-choice `Stroke of Luck -> Bardic Inspiration` concentration reaction chains before Step 2 executes, normal-control area obstruction and half-on-save outcomes, normal-control missing-grid pre-payment refusal via `combat._on_hex_clicked`, and normal-control zero-HP replacement across Natural Zombie, Created Zombie, and `sandbox:dread_husk`.
- **Stage B2B Two-Process Recovery**: `scripts/validate_ordered_grant_fresh_relaunch.ps1` and `src/ordered_grant_fresh_relaunch_probe.gd` verify across two distinct Godot child processes (`prepare` and `recover`) that legally prepared ordered spells spending real spell slots persist source-owned timed grants and concentration bindings across `GameManager.advance_campaign_time`, reload with exact manifest parity and canonical party/seat identity, refuse structured-invalid and missing-definition saves before mutating the populated live session, and expire independently on subsequent post-load campaign clock advances.
