# Batch 055: S-156 build — command authority for created creatures

Card: Q-20261021-051202-9317. Base: batch-054-factory-choices (39b8304).

## Design
- `CreatedCommandRules` (src/combat/created_command_rules.gd). A created-actor template may declare
  `command: {cost: action|bonus_action|none, range_hexes 1-24, orders ⊆ [attack, dodge], default: dodge|none, control_seconds 6-86400}`.
  Unauthored templates use `{bonus_action, 12, [attack, dodge], dodge}`.
- Commands target the exact actor id (existing `created_actors` identities). Same-named creatures are listed as `Wolf 1 [1]`, `Wolf 2 [2]`.
- `command_error` checks everything first: owner conscious, owner's turn, ownership, alive, placed, control, order allowed, range, once per turn, budget, target reach. Only after that does `issue` charge the owner's existing action budget, exactly once.
- Uncommanded actors take their declared default (dodge or none) at the end of the owner's turn.
- Control expiry: an optional `control_until` field on the record. After expiry, commands are refused and the creature stays. Nothing is deleted.
- HUD: the feature list has disabled rows that show the reason. An attack order opens a target popup with Cancel. Canceling or answering a stale popup spends nothing. The `command_created_actor` type is added to the CombatCommand whitelist.

## Checklist
- (a) Refuse before paying: all validation runs before the charge. Logic and scenario both check that a forced or stale command spends nothing and charges once.
- (b) Saved data: `control_until` and the `command` policy are validated by `CreatedActorRules.saved_record_error` → `CreatedCommandRules.saved_error`.
- (c) Production callers: `CombatState._on_hud_action`, `_end_active_turn` (apply_defaults), and the HUD `_show_feature_selection`/`request_created_command`.
- (d) Real persistence: the scenario saves and loads through SaveManager. Both wolves and their control deadline survive.

## Counts
- Logic: baseline 39b8304 = 5516/0 (imported twice); branch = 5526/0.
- Scenarios 031-055: all 25 PASSED, run one at a time.

## Limits
- No initiative for created creatures (S-157). Orders resolve right away on the owner's turn. Defaults run at the end of the owner's turn.
- Owner incapacity (S-158) is limited to refusing commands from an unconscious owner.
- The persistent animate-dead expiry path is unchanged. Fixture content only.
- Untouched: the option cap (max 3 templates), mixed creature kinds, S-120 successors, disposal triggers, S-165/S-166, tether capacity.
