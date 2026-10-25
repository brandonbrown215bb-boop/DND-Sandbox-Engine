# Batch 079 build: S-130/S-131 max-HP stacking policy (#43 follow-up)

Card Q-20261025-222012-483e. Stacked on `batch-078-declared-capacity` (PR #51, including reviewer commit 55e588a).

## Done means (Brandon's ruling, verbatim)
"require an explicit stacking policy in new max-HP definitions, keeping existing data compatible. SRD p.106: overlapping castings of the same spell use the strongest effect, and the newest wins equal-strength ties. Accumulating reductions need their own stated behavior. Display names alone must not decide. Fix the bug where replacing a weaker increase grants too much current HP; resolve it against the source."

## Design (ADR-0018: data declares, engine reads)
- **Explicit policy required for new data:** `MaxHpSourceRules.validate_rule` (content gate used by `DataLoader` monster attack riders and `SharedSpell` `max_hp_source` effects) refuses a rule without `combine` (`sum` | `highest`) and refuses a `reduction` that does not state `accumulate` (true/false). Unknown `combine` values stay refused.
- **Documented legacy path (not silent defaulting for new data):** `validate_rule(rule, true)` is used only by runtime `apply`, i.e. rules already accepted earlier or rebuilt from saves. Saved entries without `combine` keep the historical `sum`; `saved_error` accepts them. All in-repo fixtures (batch 035, 039, 071) were migrated to declare their policy explicitly.
- **Identity:** equivalence is the declared `rule.id` + kind (monster sources are `<monster id>:<rule id>`; spell sources are cast instances). Display names are never read. Proven with three fixture spells sharing the name "079 Vigor Mark": two share `b079:vigor` (combine), one is `b079:other_vigor` (not merged).
- **Strongest wins, newest breaks ties (SRD p.106):** `highest` entries carry `applied_seq` (new optional saved field, positive integer). `_beats` ranks by requested amount, then `applied_seq`, then stored order for legacy entries. Previously the first instance won ties. Recasting an older instance makes it newest.
- **Over-heal fix:** `_settle` raises current HP by `min(source change, net growth of the maximum)`. Weak +3 then strong +7 on a hurt creature now gives +3 then +4 (was +3 then +7). A weaker recast under a stronger one grants nothing.
- **Accumulating reductions:** `accumulate: true` adds repeated requests from one source; `accumulate: false` keeps the larger single request. Both must be stated.
- **Legacy saves:** no field is required; `applied_seq` is optional; legacy entries load, validate, sum and revert independently (logic + fresh-process scenario).
- **#51 nit (refuse bad capacity values):** not folded in, to keep this PR to one slice.

## Validation (Godot 4.7.2, imported twice, sequential, no concurrent Godot)
- Logic: **6270 passed, 0 failed** (+24 from `Batch079Checks` over 078's 6246). Check script gate 86/0. No SCRIPT/Parse/Compile errors in import, logic or final scenario logs.
- Scenarios:

  | Scenario | Result |
  |---|---|
  | `batch_079_max_hp_stacking_flow` (new) | PASSED, 0 FAIL |
  | `batch_079_max_hp_stacking_reload` (new, fresh process) | PASSED, 0 FAIL |
  | `batch_071_monster_max_hp_flow` | PASSED |
  | `batch_071_monster_max_hp_reload` | PASSED |
  | `batch_035_profile_max_hp_flow` | PASSED |
  | `batch_039_created_actor_flow` | PASSED |

- The new flow casts through the real `SpellResolver` on a party character: weak +3 (5/15), stronger replacement +4 net (9/19), equal-strength recast with the newest active, same-name different-source +2; installs a legacy (pre-079) source record on a second character; real `SaveManager` save and load; the reload scenario rebuilds once in a fresh process, validates the legacy record, ends every casting back to base and reverts legacy sources independently.
- Logic covers: missing `combine` refused (rule and spell content), reduction without `accumulate` refused, unknown policy refused, strongest wins in both orders and weaker resumes, tie newest-wins plus JSON round trip and recast, bad saved order refused, over-heal fix, display-name non-merge, accumulate true/false, legacy save.

## PARTIAL (still open)
- "Strongest" compares requested amounts within one rule id; there is no cross-spell potency ranking for different effects.
- `damage_dealt` sources rank by the rolled amount.
- Legacy content/saves without `combine` keep the historical sum (documented path).
- Monster periodic/cure events and monster-attack sources on monsters remain PARTIAL (batch 071).
- Slice status unchanged.
