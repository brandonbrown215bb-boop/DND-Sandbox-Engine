# Batch 061 build: S-157 summon turn timing

Card Q-20261021-151048-b151. Queue item 3. Stacked on #32 (batch-060-command-cost @ 3aef650, accepted by Runtime Reviewer, not merged), because #25-#32 are still open and this edits the 056/058/060 command code.

## Finish line (verbatim)
"When a summon acts in initiative should be definable in the data (for example, right after its owner)."

## Design
- **Field: `command.initiative`** on each creature template (introduced by 056, now documented as the template's turn timing). Values, reusing the 056 modes:
  - `owner_turn`: no turn of its own; orders resolve on the owner's turn (055 behaviour, the default when absent).
  - `after_owner`: its own turn directly after its owner, sharing the owner's count (SRD 5.2.1 summon text, e.g. Giant Insect / Summon Dragon / Animate Objects: "shares your Initiative count, but it takes its turn immediately after yours").
  - `own`: rolls its own d20 + DEX.
- No new vocabulary was added: the three modes already cover "shares owner turn", "right after owner" and "own initiative roll". The loader (`CreatedCommandRules.policy_error`) refuses anything else (`first`, `shares_owner_turn`, `""`, `1`, wrong case).
- **Mixed casts.** The 058 rule (one shared command policy per cast) now compares `CreatedCommandRules.shared_policy(t)`, which reads `free` as `none` (in `cost` and `order_costs`) and an absent `initiative` as `owner_turn`. Different timings (e.g. `after_owner` + `own`, or absent + `after_owner`) and real cost differences are still refused. Comparison-only: the stored policy keeps the authored spelling.
- **Production callers.** `CreatedActorRules.mix_error` → `shared_policy`; timing is read by `CreatedCommandRules.initiative` → `join_initiative`, called from `CreatedActorRules.attach` (mid-combat cast) and `CombatState` combat start.
- ADR-0018: no per-ID branches; timing comes from template JSON. SRD citation only for the after_owner wording quoted above (present in `data/core/spells/srd_additional_spells.json`).
- Fixture `fixture:b061_insects` (mix of Spider and Wasp, both `after_owner`, costs spelled `free` and `none`).

## Checklist
- (a) Refuse before paying: the scenario cancels a real HUD mixed cast at the second kind and asserts no slot spent, no actors and an unchanged turn order. A mixed cast with mismatched timing is refused at load, so it can never be cast. Command-payment refusals are unchanged from 060.
- (b) No new saved record or field. Timing is read from the template; the logic check asserts `saved_record_error` is clean and the record contains no `initiative`.
- (c) `shared_policy` is called by `CreatedActorRules.mix_error` (loader). No other new functions.
- (d) Real `SaveManager.save_game`/`load_game` in `batch_061_summon_timing_flow`: both reloaded kinds still resolve `after_owner` and rejoin initiative right after the owner via the real `join_initiative`. No cache clearing.
- (e) Merged/suppressed item gate: not relevant; no item-granted effects.
- Legacy: a template without `initiative` (055 pack) keeps `owner_turn` and adds no turns (asserted). 056 after_owner/own scenarios pass unchanged. No save format change.

## Counts
- Baseline 3aef650 (fresh worktree, imported twice): logic 5588/0, 57 check scripts.
- Branch (imported twice): logic 5595 passed, 0 failed (+7, all 061), 58 check scripts, 0 failed.
- Scenarios 031-061, one at a time: 31/31 SCENARIO PASSED (new: `batch_061_summon_timing_flow`, 4 assertions).
- 0 SCRIPT/Parse/Compile errors in all logs.

## Limits
- Save is still refused mid-combat (unchanged SaveManager rule), so "turn order persists" means the declared timing survives save/load and rebuilds the same order; a mid-round save of the live tracker is card 0ca9 (not in scope).
- Summons that exist before combat starts are not added to a new combat's player entities by this batch (unchanged); timing applies once they are in combat.
- One timing per mixed cast (058 shared-policy rule); per-kind timing differs only across casts.
- Fixture only; no core SRD summon spell is converted to `after_owner` here (056 open question on authored SRD defaults still stands).

## Carried limits
- 059 review: bodies are consumed before placement (latent while placement is all-or-nothing).
- 058: mixed-size summons unsupported; Find Familiar creature-type choice has no building block. Documented only.
- 060: Reaction and Magic action are not command costs yet (queue items 6 and 5).
