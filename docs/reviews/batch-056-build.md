# Batch 056: S-157/S-158 build — created-creature initiative and owner incapacity

Card: Q-20261021-053147-dc76. Base: batch-055-created-commands (63a50c6), because #25-#27 are still open.

## Design (`CreatedCommandRules`)
New optional keys on the template's `command` policy:
- `initiative`: one of these three:
  - `owner_turn` (default; 055 behaviour, where orders resolve at once on the owner's turn)
  - `after_owner` (each actor gets its own tracker entry directly after its owner and earlier linked actors)
  - `own` (rolls d20+DEX and is sorted with the active combatant preserved)
- `owner_incapacitated`, `owner_dead`, `control_expired`: each is `dodge`, `none` or `attack_nearest`. A missing key falls back to the declared `default`.
- `concentration_end`: only `end` is supported. The actor ends with its source through the existing cleanup. Outliving concentration would be a disposal change, which is off-limits.

How it plays:
- **Orders:** an order to an own-turn actor is paid by the owner once on the owner's turn. It is stored in transient state that is never saved, and it runs on the actor's turn. If the order is impossible by then (for example, the target is gone or out of reach), the actor uses its declared behaviour instead.
- **Separate budgets:** an actor's own turn spends its own Action (the turn budget is reset for the actor), never the owner's.
- **Owner-turn actors** keep 055's end-of-owner-turn default, now chosen by the owner's state. 055's unauthored default, including the Bonus Action cost, is unchanged.
- **Sources ending mid-round:** `reconcile` removes battlefield and tracker entries whose source ended. It runs in `_end_active_turn` before the tracker advances, so a removal never replays or skips a turn.

Wiring:
- `_roll_initiative_and_start` no longer rolls created actors as players. It joins them by policy.
- `CreatedActorRules.attach` joins newly created actors mid-combat.
- `_start_combat_turn` runs `take_turn` for created-actor entries.
- `CombatCommand` is unchanged.

## Checklist
- **(a) Refuse before pay:** an unconscious or dead owner's command is refused before the cost, so nothing is spent. Logic and scenario both check this. A valid order charges the owner once.
- **(b) Saved data:** the new policy keys live in template data and go through `policy_error`/`template_error`. The saved record is unchanged and still validates through `saved_record_error`. Pending orders are transient.
- **(c) Production callers:**
  - `join_initiative`: called by `attach` and `_roll_initiative_and_start`.
  - `take_turn`: called by `_start_combat_turn`.
  - `reconcile`: called by `_end_active_turn`.
  - `behaviour`/`act`: called by `apply_defaults` and `take_turn`.
- **(d) Real persistence:** the scenario saves and loads through SaveManager. Both hounds survive, and no orders are saved.

## Counts
- Logic: the baseline at 63a50c6 is 5527 passed, 0 failed (fresh worktree, imported twice). The branch is 5540 passed, 0 failed (13 new checks).
- Scenarios 031-056: all 26 passed, run one at a time. 056 has 10 of 10 checks passing.

## Runtime tests requested by the reviewer
Logic and scenario both cover each case:
- **Unconscious owner:** the hound takes its declared `attack_nearest` turn, and the owner's command is refused with nothing spent.
- **Dead owner:** the hounds take their declared `none` turns and are not deleted.
- **Concentration end:** an `own` sprite is removed mid-turn, and the next combatant acts as planned.

## Limits
- Fixture content only, and the orders are still only attack and dodge.
- The `after_owner` tie-break is the owner's roll with DEX minus 0.01. A later re-sort keeps it directly behind the owner unless another combatant has the same roll and DEX in between.
- An owner's own concentration still drops through existing rules when the owner falls unconscious. A concentration creature therefore leaves rather than acting on `owner_incapacitated`. The test hounds are non-concentration for that reason.
- If a dead owner is removed from the tracker, `owner_turn` actors have no turn-end trigger.
- The persistent animate-dead path is unchanged, and 055's rule that control expiry doesn't delete a persistent creature holds.
- Untouched: the option cap, mixed kinds, 055's default command cost, S-120, disposal, S-165/S-166 and tether capacity.
