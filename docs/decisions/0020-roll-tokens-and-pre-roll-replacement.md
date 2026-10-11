# 0020 — Roll tokens and pre-roll D20 Test replacement

- **Status:** Accepted
- **Date:** 2026-10-10
- **Affects:** [ADR-0004](0004-staged-2024-rules-and-save-boundary.md), [ADR-0006](0006-composable-class-features.md), [ADR-0018](0018-shared-data-driven-rules-runtime.md), [ADR-0019](0019-shared-ordered-execution-and-zero-hp-replacement.md)

## Context

The 2024 Wizard **Diviner** subclass introduces **Portent** (Level 3) and **Greater Portent** (Level 14):

- **Portent (Level 3):** *"Whenever you finish a Long Rest, roll two d20s and record the numbers rolled. You can replace any D20 Test made by you or a creature that you can see with one of these foretelling rolls. You must choose to do so before the roll, and you can replace a roll in this way only once per turn. Each foretelling roll can be used only once. When you finish a Long Rest, you lose any unused foretelling rolls."*
- **Greater Portent (Level 14):** *"The visions in your dreams intensify and paint a more accurate picture in your mind of what is to come. You roll three d20s for your Portent feature, rather than two."*

### Pinned Source and Correction Ledger

- **Primary Subclass Clause Source:** Licensed 2024 PHB Diviner compendium page (`https://roll20.net/compendium/dnd5e/Subclasses:Diviner?expansion=32231`, inspected 2026-10-09). This supplies the Portent and Greater Portent clauses above; full PHB subclass corpus certification remains outside SRD 5.2.1, so unsupported Diviner features stay `"enabled": false` and `"rules_status": "2024-partial"`.
- **Official Errata Inspection:** D&D Beyond Sage Advice & Errata hub (`https://www.dndbeyond.com/sources/dnd/sae`, updated Oct 7, 2026), current Player's Handbook errata page (`https://www.dndbeyond.com/sources/dnd/sae/players-handbook`), and current PDF (`https://media.dndbeyond.com/compendium-images/phb/downloads/Errata%20-%20Player%27s%20Handbook%205.5e.pdf`, inspected 2026-10-09) list no changes to Portent or Greater Portent.
- **Official Sage Advice Inspection:** Sage Advice Compendium (`https://www.dndbeyond.com/sources/dnd/sae/sage-advice-compendium`, inspected 2026-10-09/10) confirms Portent visibility has no distance restriction. The runtime therefore enforces modeled sight (`CombatPerception.can_see_target` on a grid, or non-blinded / target-not-unperceived-invisible fallback off-grid) without inventing a range cap.
- **SRD 5.2.1 and implementation limit:** Official SRD 5.2.1 (`https://media.dndbeyond.com/compendium-images/srd/5.2/SRD_CC_v5.2.1.pdf`) defines D20 Tests, Initiative and Death Saving Throws, and describes one-die replacement under Advantage/Disadvantage. The shipped token runtime instead substitutes the stored natural result without rolling another d20, retaining modifiers and natural-result distinctions. This is the project's current adjudication, not a claim that the generic SRD replacement clause certifies that interpretation of Portent.

**Documentation correction, 2026-10-11:** This version supersedes this ADR's
earlier rest-only acquisition and one-die replacement proposals to describe the
existing production behavior also documented in `docs/mechanics/wizard-2024.md`.
Token identity, once-per-turn costs, visibility, source ownership and save
validation guarantees remain binding. Rest-only acquisition and one-die
Advantage/Disadvantage replacement are not implemented.

Under [ADR-0018](0018-shared-data-driven-rules-runtime.md), pre-roll d20 replacement and rest-generated roll tokens belong in a shared data-driven runtime primitive (`roll_token_pool` and `roll_token_pool_upgrade`) rather than a Wizard-only or Diviner-named switch. A non-production fixture subclass (`fixture:oracle`) must be able to exercise the same pool generation, pre-roll replacement, target predicate, and save validation rules without new GDScript branches.

## Decision

### 1. Data-Driven Effect Schema

`DataLoader` validates two passive feature effect types:

- `roll_token_pool`:
  - `pool_id` (required identifier)
  - `die_sides` (must equal `20` for D20 Test replacement)
  - `token_count` (`1..10`) or `token_count_by_level` (`1..20 -> 1..10`)
  - `generation_timing` (`"long_rest"`)
  - `target_predicate` (`"any_visible"`, `"self_only"`, `"ally_visible"`, or `"enemy_visible"`)
  - `uses_per_turn` (`1..10`)
- `roll_token_pool_upgrade`:
  - `pool_id` (required identifier matching an earlier or same-level `roll_token_pool` on the class or subclass)
  - `token_count` (`1..10`)

In `data/core/subclasses/diviner.json`, `diviner_portent` (Level 3) declares `roll_token_pool` (`pool_id: "diviner_portent"`, `die_sides: 20`, `token_count: 2`, `generation_timing: "long_rest"`, `target_predicate: "any_visible"`, `uses_per_turn: 1`) and `diviner_greater_portent` (Level 14) declares `roll_token_pool_upgrade` (`pool_id: "diviner_portent"`, `token_count: 3`). Unsupported Diviner features (`diviner_divination_savant`, `diviner_expert_divination`, `diviner_the_third_eye`) remain `"enabled": false` and `"rules_status": "2024-partial"`.

### 2. Token Generation and Acquisition Timing

- Characters are created at Level 1 before subclass acquisition. A Long Rest completed before acquiring a `roll_token_pool` feature does not generate tokens.
- Acquiring a `roll_token_pool` feature generates its initial capacity immediately. Upgrading the pool preserves any unspent tokens and generates the additional capacity immediately. This is the current game behavior; it does not implement the stricter rest-only acquisition proposal.
- Whenever a character owning a `roll_token_pool` finishes a Long Rest, any unused tokens in that pool are discarded and replaced with newly rolled d20 tokens up to the character's current pool capacity. Short Rests do not regenerate or discard `long_rest` roll tokens.

### 3. Distinct Token Identity and Pre-Roll D20 Test Replacement

- Each generated token is stored in `Character.roll_tokens[pool_id]` as `{ "token_id": "<pool_id>:<serial>:<index>", "value": int, "feature_id": String, "pool_id": String, "die_sides": 20 }`.
- Equal numeric rolls (for example `[14, 14]`) have distinct `token_id`s. Spending one token removes only that specific `token_id`; a duplicate or stale request for the spent `token_id` is refused without consuming the remaining equal-valued token.
- `RollTokenRules` intercepts all six D20 Test boundaries before the d20 roll occurs:
  1. Attack rolls (`Character.make_attack_roll`, including player, monster, and spell attack rolls)
  2. Character saving throws (`Character.make_saving_throw_result` / `saving_throw_test_to_dc` / `make_saving_throw`)
  3. Monster saving throws (`BarbarianRules.roll_monster_save_result` / `roll_monster_save`)
  4. Ability and skill checks (`EventResolver.resolve_skill_check`)
  5. Initiative Dexterity checks (`CombatState._roll_initiative_and_start` / `RollTokenRules.roll_initiative_d20`)
  6. Death saving throws (`Character.make_death_save`)
- **Eligibility:** The token owner must be alive, must not be Incapacitated/Unconscious when replacing a roll, must have remaining `uses_per_turn` on the current `CombatAction.active_turn_serial`, and must satisfy `target_predicate` and sight (`target == owner`, or `owner` can see the living/downed roller via `CombatPerception.can_see_target` when a `HexGrid` is present or non-blinded / target-not-unperceived-invisible fallback when no grid is present, with no distance limit).
- **Stored natural result replacement:** The replaced d20 equals `token_value` and no random d20 is rolled (`rolls = [token_value]`, `kept = [true]`), including under Advantage/Disadvantage. This runtime policy replaces the earlier one-die proposal, subject to the rules interpretation limit above.
- **Ordered spells:** Each eligible attack, target save and damage-triggered concentration save suspends before rolling. The owner may decline an early choice and spend a token on a later test within the same cast. Owned request settlement resumes the exact step and actor without repeating earlier effects or costs; encounter teardown invalidates outstanding requests.
- **Ordering and conflicts:** Multiple competing token replacements on the same D20 Test are refused before any token is spent. Modifiers (`Bless`, `Bane`, ability/proficiency, `Blade Ward`, check floors) apply after the d20 is settled, and post-roll features (`Indomitable`, `Disciplined Survivor`, `Seeking Spell`, `Stroke of Luck`, `Bardic Inspiration`, `Heroic Inspiration`) observe the resulting test.

### 4. Save Compatibility and Preflight Validation

- `Character.to_dict()` and `Character.from_dict()` persist `roll_tokens` and `roll_token_generation_serial` within schema version 2 (`SaveManager.CURRENT_SCHEMA_VERSION == 2`). Existing schema-2 saves without those fields default to `{}` and `0` with no migration.
- `ClassProgression.saved_choices_error(dto)` invokes `RollTokenRules.saved_state_error(dto, data, subclass, level)` during `SaveManager.load_game` preflight. Malformed `roll_tokens` (non-Dictionary payloads, unowned `pool_id` or `feature_id`, token counts exceeding level capacity, non-integer/boolean or out-of-range `< 1` or `> 20` values, or duplicate `token_id`s) are rejected before `PartyManager` or `PlayerManager` state is mutated.

## Acceptance Boundary

1. `diviner.json` and `fixture:oracle` pass `DataLoader` schema and cross-reference validation; malformed `roll_token_pool` and `roll_token_pool_upgrade` definitions fail validation cleanly.
2. Acquiring Portent generates 2 initial tokens; Greater Portent adds the third without rerolling unspent tokens. Finishing a Long Rest generates the current capacity, discarding unspent tokens; Short Rest preserves unspent tokens. Rest-only acquisition remains a rules limitation.
3. Pre-roll token replacement works across all six D20 Test families, enforces once-per-turn per owner pool, visibility, and target predicates, substitutes the stored natural result without another d20, preserves duplicate-value token identity, and refuses competing replacements. The general SRD one-die replacement interpretation remains a rules limitation.
4. Normal UI controls expose Diviner/Oracle subclass selection, Character Sheet and Combat HUD token inspection, and pre-roll replacement prompts in combat.
5. Corrupt `roll_tokens` save payloads fail preflight without mutating live party state, and valid spent/unspent token state survives a two-process fresh-relaunch save/load round-trip.
