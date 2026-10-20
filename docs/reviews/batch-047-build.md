# Batch 047 build: HUD form/equipment chooser (card Q-20261020-173959-7e2c)

Base: `origin/main` @ 10f9bd3 (PRs #1–#15 merged). This is not a stacked PR.

## Finish line
"Normal casting controls let you choose among declared forms and equipment policies. Canceling or answering an old popup spends nothing. Currently multi-option content refuses because the UI never offers the choice."

## Design
- `SpellCastChoices.choose_projection_options(cast)` runs in `SpellCastPreparation.validate_and_choose`, straight after `validate_host` and before `validate_actor`.
  - That ordering keeps it before `ActorProjectionRules.cast_error` and before every slot or action payment.
- For an `actor_projection` spell with more than one declared form, it opens the shared HUD popup **"Choose a form"**.
- It then opens **"Choose how equipment is handled"** when more than one legal equipment policy is declared.
- Each popup lists **Cancel** followed by exactly the declared options, in their declared order.
- The picks are written only onto that cast's own spell copy, as `_projection_form_id` and `_projection_equipment`. Each cast clears both keys first, so nothing carries over, and shared DataLoader content is never mutated.
- A single-option projection opens no popup and casts as before.
- When the caster is already in another form, the chooser steps aside and `validate_actor` refuses as before.
- **Cancel** (the Cancel item or closing the popup):
  - logs "Casting canceled; nothing was spent."
  - clears pending state exactly like the existing Dancing Lights chooser
  - returns before any cost is paid
- **Stale answer:** a popup counts as stale when a newer projection chooser opened after it (request serial), or when the cast's own `commit_guard` fails (the turn ended or the actor changed).
  - Its answer is discarded with "That choice is no longer current; nothing was spent."
  - It returns without touching the newer cast's pending controls.
- `projection_options(spell)` is the single source of the listed options and their labels.

## Mandatory checklist
- **(a) Refuse or abandon before paying.**
  - Cancel and stale answers return from preparation before `SpellCastResources.commit_spell_resource` and any Action spend.
  - The scenario asserts the slot and Action are unspent after each of the following, and that no projection is applied:
    - canceling the form popup
    - canceling the equipment popup
    - answering a stale popup superseded by a newer chooser
    - answering a popup after its turn ended
  - After the stale answer, the current chooser still casts the chosen Hare/worn and pays exactly one slot.
- **(b) Records.** This batch adds no new nested inventory or save record. The existing projection record, with its form and equipment policy, still goes through its existing validators. The real save and load in the scenario keeps the chosen Boar/merged.
- **(c) Production callers.**
  - `choose_projection_options` is called from `validate_and_choose`.
  - `_ask_projection` and `projection_options` are called from `choose_projection_options`.
- **(d) Real persistence.** The scenario uses a real `SaveManager.save_game`/`load_game` of the chosen projection, with no cache clearing.

## Changed earlier scenarios
- 040 and 041 asserted that the HUD **refused** multi-option casts because no chooser existed. That is exactly the behavior this card removes.
- Both now open the real chooser and **cancel** it, and they keep their original assertions: unprojected, slot unspent.
- Each scenario's `[ok]` count drops by one because it no longer calls the shared 036 cast helper's "finishes" assertion: 040 goes from 13 to 12, and 041 from 11 to 10.

## Validation (Godot runs strictly one at a time)
- **Full logic suite:** 5367 passed, 0 failed. It was re-run after the last scenario edit.
- **Fresh baseline (origin/main 10f9bd3, run alone):** 5362 passed, 0 failed.
  - The difference is +5, matching the 5 `check.call` lines in batch_047_checks.gd.
- **Scenarios:**

  | Scenario | ok |
  |---|---|
  | 031 | 25 |
  | 032 | 33 |
  | 033 | 70 |
  | 034 | 10 |
  | 035 | 9 |
  | 036 | 7 |
  | 037 | 11 |
  | 038 | 7 |
  | 039 | 10 |
  | 040 | 12 |
  | 041 | 10 |
  | 042 | 10 |
  | 043 | 11 |
  | 044 | 12 |
  | 045 | 16 |
  | 046 | 16 |
  | 047 | 10 |
  | shared_spell_flow | 67 |

  There were 0 FAIL lines and 0 SCRIPT/Parse errors.

## Values
The new fixture `fixture:b047_changeling` has two neutral forms and the merged/worn policies. All of its values are fixture values, and no SRD numbers are claimed.

## Limits
- The chooser covers only `actor_projection` forms and equipment. It is not the F1 resolver, and F1 mode_choice and rule_alternatives remain off-limits.
- It is offered only in combat-HUD casting, because there is no out-of-combat cast UI.
- The labels are summaries (size, type and speed; a one-line equipment policy). There is no stat preview.
- The turn-ended stale case is simulated in the scenario by advancing `CombatAction.active_turn_serial`, which is what a turn start does.
- The 30-second popup timeout behaves the same as Cancel.
