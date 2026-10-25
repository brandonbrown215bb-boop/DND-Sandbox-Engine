# Extra Attack count and base-AC upgrades (S-084/S-085, batch 070)

Status: **PARTIAL** — the data fields and consumers below are supported; the gaps listed at the end are not.

## Data fields
A `rule_upgrade` feature may carry a *consumer change* instead of mode changes:

| Field | Shape | Consumer |
|---|---|---|
| `changes.attack_count` | `{"set": 1..3}` | `RuleUpgradeRules.extra_attacks(actor)` → combat Attack action swings (`CombatState`) |
| `changes.base_ac` | `{"set": {"base": 0..20, "abilities": [1-3 unique of STR/DEX/CON/INT/WIS/CHA], "allows_shield": bool}}` | `Character._equipment_base_ac` unarmored branch via `RuleUpgradeRules.base_ac_formula` |

Rules (ADR-0018 — no per-ID branches, no engine defaults):
- `rule` names a passive feature carrying an `extra_attack` (for `attack_count`) or `unarmored_defense` (for `base_ac`) effect. Item-owned consumer upgrades may name a rule the wearer owns (not local to the item); mode upgrades still must be local.
- A consumer change requires `exclusive_group` and cannot be mixed with mode changes. Only one option of a group applies (SRD 5.2.1 "Only One Base AC… must choose which one"; Extra Attack features don't stack). With no saved choice the lowest-id option applies.
- `attack_count.set` is the extra-attack count the feature supplies while chosen; the base `extra_attacks` stat is never rewritten. Class sources still combine with `maxi`.
- `base_ac` applies only unarmored; `allows_shield: false` with a shield equipped falls back to 10 + DEX.

## Controls and costs
- The HUD feature list and room mode controls show passive consumer rules as "Rule: <name>" offering only *Choose upgrade*. Cancel / stale-token answers change nothing.
- Switching mid-Attack-action: remaining swings = min(remaining, new total − spent). A switch never refunds a spent swing or supplies a new Attack action; removal mid-action is reclamped on the next attack click.

## Ownership, removal, reload
- Item upgrades pass the `OwnedFeatureSources.copy_active` gate (attunement, merged/suppressed via `MagicPropertyRules`). Suppression reverts the values live.
- Removing the copy prunes its chosen option from the actor and stamps it on `record.state.rule_alternatives` (validated by `InventoryCopies.record_state_error`); re-wearing restores it.
- Saves: `rule_alternatives` checked by `RuleUpgradeRules.saved_error` on both load paths; legacy saves without it load with first-option defaults per group.

## Not supported (PARTIAL)
- Mid-turn combat state (remaining swings) is not saved.
- Ungrouped consumer upgrades are refused.
- Barbarian Unarmored Defense content has empty effects, so no shipped class uses `base_ac` yet; only the first `unarmored_defense` feature is a consumer.
- Armored base-AC alternatives and reach/mastery consumers are out of scope.
