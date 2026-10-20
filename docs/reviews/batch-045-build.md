# Batch 045 build: S-064 / S-168

Base: `batch-044-s210-s203` @ c3e88d1 (stacks on #12).

## Selection
- **S-064 (active-time budgets):** deps S-014 (verified baseline) and S-049 (Verified) are met. It unblocks S-197.
- **S-168 (tethered restraint):** deps S-026, S-028 and S-072 are verified. It unblocks S-169 and S-170.
- **S-067 not picked:** it needs S-066, which is not built yet.
- **Collisions:** none with the excluded areas (content_editor, wand charges, F1 mode_choice, Druid/Wild Shape, S-120 successors, BondRules disposal, S-165/S-166).

## Design
- `ActiveTimeRules` (src/characters/active_time_rules.gd)
  - Item policy: `active_time {budget_seconds, cooldown_seconds?}`.
  - activate / pause / settle. `settle` is driven by `GameManager.advance_campaign_time` and runs at 6 s per combat round.
  - Item benefits apply only while active, gated in SourceBenefitRules.
  - Budget exhaustion starts the cooldown, and usage resets when the cooldown ends. Without a cooldown, usage never resets.
- `TetherRules` (src/characters/tether_rules.gd)
  - Shared spell effect: `bind_tether`.
  - It grants the declared condition under the cast source and stores `caster.tethers[source]`.
  - A tether lasts only while the caster concentrates on that source.
  - Capacity is enforced in `ActorProjectionRules.cast_error`.
  - Range is enforced each round.
  - Escape uses the best of the declared abilities against the DC: characters spend an Action from the HUD, and monsters try on their turn.
  - Tethers are saved and restored with the character and validated by SaveManager.

## Mandatory checklist
- **(a) Refuse before paying.**
  - `TetherRules.cast_error` (capacity) runs inside `ActorProjectionRules.cast_error` before any slot is spent. The scenario asserts the slot count is unchanged after a refused second cast.
  - `ActiveTimeRules.activate_error` refuses before any state changes. The scenario asserts a refused activation of the spent lamp leaves its used time and state unchanged.
- **(b) Records validated.** `ActiveTimeRules.record_error` is called from `InventoryCopies.record_state_error`. Tether save records go through `TetherRules.saved_error` in both SaveManager paths. `tethers` lives on the character, not in inventory.
- **(c) Production callers.** The coverage grep found every public function in both new files called from non-test code (combat_state, game_manager, shared_spell, character, save_manager, inventory_copies, source_benefit_rules, local_room_view, actor_projection_rules), or used internally by such a function.
- **(d) Real persistence.** The scenario saves and loads through SaveManager with a live tether and paused active time, with no cache clearing, then advances time and resumes.

## Validation
- **Full logic suite:** 5288 passed, 0 failed.
- **Baseline at c3e88d1:** 5258 passed, 3 failed, 5261 tests in total.
  - The 3 failures are LogPanel UI tests that were run in parallel and are unrelated.
  - The delta is +27, matching the 27 `check.call` lines in batch_045_checks.gd.
- **Scenarios:** 031:25, 032:33, 033:70, 034:10, 035:9, 036:7, 037:11, 038:7, 039:10, 040:13, 041:11, 042:9, 043:11, 044:12, 045:14, shared_spell_flow:67. No scenario failures.
- **Error grep:** 0 SCRIPT ERROR / Parse Error.

## Values
All thresholds are fixture values (budgets, cooldowns, range, capacity, DC source). No SRD numbers are claimed, and no grapple values from SRD 5.2.1 are used.

## Limits
- Only "restrained" tethers, and only through a fixture spell. There is no grapple action.
- Range is enforced only at round ticks.
- Escape targets the first binding tether.
- Active time applies only to item copies, and benefits apply only while equipped.
- Activate/Pause is available only from the local-room HUD.
- Item types are fixtures (F3).
