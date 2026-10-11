# ADR-0022: Bounded Rest Completion and Triggered Slot Recovery

## Status

Accepted

## Context

Prior to Slice 4, exploration resting in `OverworldState` and `DungeonState` immediately executed an 8-hour Long Rest (`28800` seconds) whenever the HUD `Rest` control was pressed, with no player-reachable Short Rest completion path in normal controls. Meanwhile, `Character.short_rest()` existed only as a direct method call, and `wizard_arcane_recovery` in `data/core/classes/wizard.json` was marked `"2024-partial"` with a hardcoded `DataLoader.CURATED_FEATURE_EFFECTS` injection (`recover_spell_slots`) and a combat-only helper (`CombatState._recover_wizard_spell_slots`) that automatically restored highest-level missing slots during combat.

Under SRD 5.2.1 (2024) and ADR-0018:
- A **Short Rest** is a 1-hour (`3600`-second) rest period outside combat during which living creatures with at least 1 Hit Point recover short-rest resources and trigger short-rest completion features.
- **Wizard Arcane Recovery** (`wizard_arcane_recovery`) triggers when the Wizard finishes a Short Rest (`trigger: "short_rest_completed"`), once per Long Rest, allowing the player to choose expended spell slots to recover whose combined levels are no more than `ceil(wizard_level / 2)` (`budget_formula: "half_class_level_ceil"`), with no slot of level 6 or higher (`max_slot_level: 5`).

## Decision

### 1. Shared Rest Completion Runtime (`RestRules`)

`src/characters/rest_rules.gd` (`class_name RestRules`) is the single runtime owner for exploration rest eligibility, rest-type selection, Short Rest completion, and post-rest `rest_slot_recovery` windows:

- **Normal-Controls Rest Selection**: Pressing `Rest` in `OverworldState` or `DungeonState` opens a bounded rest-choice modal offering **Short Rest (1 Hour)** (`3600` seconds), **Long Rest (8 Hours)** (`28800` seconds), or **Cancel**. Direct `PlayerCommand.rest(rest_type)`, `PlayerCommand.short_rest()`, and `PlayerCommand.long_rest()` intents execute through the same state handlers.
- **Refusal Boundaries**: Rest initiation and completion are refused when:
  - `GameManager.current_state == GameManager.GameState.COMBAT`
  - `DungeonState.local_view != null` (party is inside a tactical local room rather than the dungeon entrance/map)
  - `OverworldState.companion_roster_open` is true
  - Another rest choice or slot-recovery modal window is already open (`RestRules.is_rest_window_open()`)
  - No living party members with `current_hp > 0` exist
  - The player cancels the rest-choice modal
- **Short Rest Settlement**: Completing a Short Rest:
  1. Advances `GameManager.advance_campaign_time(3600)` exactly once.
  2. Calls `short_rest()` once on each eligible living party `Character` (`not is_dead() and current_hp > 0`, excluding summoned `familiar` / `steed` actors).
  3. Emits a source-attributed typed completed-rest event (`trigger: "short_rest_completed"`, `rest_type: "short_rest"`, `elapsed_seconds: 3600`, `campaign_elapsed_seconds`, `participants`).
  4. Evaluates any owned `rest_slot_recovery` effects triggered by `"short_rest_completed"`.
- **Explicit Scope Boundary**: Hit Dice spending during a Short Rest remains outside this slice and is not silently invented. Existing `Character.short_rest()` hooks (short-rest feature cadences, `short_rest_recharge`, `short_rest_recovery`, Pact Magic slots, Focus Points, `RollTokenRules.generate_for_rest`, and level 5+ `wizard_memorize_spell_pending`) run once per participant.

### 2. Source-Defined `rest_slot_recovery` Effect and Bounded Window

Features that recover spell slots upon finishing a rest declare a `rest_slot_recovery` effect in JSON:

```json
{
  "type": "rest_slot_recovery",
  "trigger": "short_rest_completed",
  "class_level_source": "wizard",
  "budget_formula": "half_class_level_ceil",
  "min_slot_level": 1,
  "max_slot_level": 5
}
```

- **Class-Level Boundary**: `Character.get_class_level(target_class_id)` resolves the character's level in `target_class_id` (`level` when `class_id == target_class_id`, `0` otherwise). While multiclass progression remains outside the current milestone, `rest_slot_recovery` queries `get_class_level(class_level_source)` rather than total character level so the class-specific recovery budget boundary is preserved.
- **Eligibility & Prompt Suppression**: When a Short Rest finishes, `RestRules` checks whether the character has remaining uses of the recovery feature pool and at least one expended (missing) spell slot within `min_slot_level..mini(max_slot_level, budget)` compared against `Character.get_max_spell_slots()`. If no eligible slots are missing or no feature uses remain, no prompt opens and no feature use is spent.
- **Single-Submission Window & Validation**: When eligible, `RestRules` opens a bounded window keyed by `request_id`, `epoch`, `owner_id`, and `feature_id`. Before mutating `spell_slots` or spending `feature_uses`, `RestRules` validates that:
  - The window is open, unsettled, and matches the active `epoch` / `request_id` and owning `Character`.
  - Every requested slot level is an integer in `min_slot_level..max_slot_level` (rejecting levels 6–9 for Arcane Recovery).
  - Every requested slot count is a positive integer not exceeding the character's currently expended slots at that level.
  - The combined slot-level sum (`sum(slot_level * count)`) does not exceed `budget`.
- **Confirm vs Decline**: Confirming a valid non-empty slot combination restores the exact chosen slots and spends the feature use (`character.use_feature(feature_id)`), which remains `0` across subsequent Short Rests until restored by `long_rest()`. Declining/cancelling closes the window for that rest without spending the feature use.
- **Single Execution Owner**: `wizard_arcane_recovery` is removed from `DataLoader.CURATED_FEATURE_EFFECTS`, excluded from combat action lists in `CombatHUD`, and retired from `CombatState._recover_wizard_spell_slots`.

## Consequences

- Short Rest and Wizard Arcane Recovery are player-reachable from normal Overworld and Dungeon controls and persisted cleanly through existing `spell_slots`, `feature_uses`, and `campaign_elapsed_seconds` save fields.
- Second consumers (such as `fixture:leyline_savant` in `data/fixtures/class_building_blocks/subclasses/leyline_savant.json`) execute through the same `RestRules` runtime without content-ID switches.
