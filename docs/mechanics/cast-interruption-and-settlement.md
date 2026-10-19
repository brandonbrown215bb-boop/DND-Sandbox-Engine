# Cast Interruption, Negation and Settlement (Batch 029)

This document describes the runtime contracts and data structures for Batch 029 vocabulary slices:
- **S-142** (V-031): Interruption/failure reserve and refund
- **S-115** (V-019): Whole pending cast cancellation
- **S-143** (V-031): Stopping-spell success/failure cost policy
- **S-116** (V-019): One recipient's incoming effect negation

---

## 1. S-142: Interruption/Failure Reserve and Refund

### Settlement Policies
When a spell begins resolution, `CastInterruptionRules.reserve_cast_payment(cast, payment)` records the upfront payment mode and identity:
- `slot`: ordinary or pact spell slots
- `free_cast`: feature-granted free casts (e.g. Signature Spells)
- `item_charges`: staff/wand/item charges
- `points`: Sorcery points or class pool points

Declared policies:
- `interruption_policy`: `"refund"` | `"commit"` (default: `"commit"`; canonical Counterspell refunds the actual target slot when no target policy overrides it)
- `failure_policy`: `"refund"` | `"commit"` (default: `"commit"`)
- `empty_effect_policy`: `"commit"` | `"refund"` (default: `"commit"`)
- `cast_settlement`: Fine-grained object specifying `on_success`, `on_failure`, `on_interrupted`, `on_negated` branches for each resource type.

Empty effect payloads commit by default unless an explicit refund policy is declared.
The payment owner records what was actually spent. Refunds restore that exact
pool/source/copy and amount once; unpaid metadata cannot create a refund. Target
Action/Bonus Action costs remain spent. Target `cast_settlement` branches support
`slot`, `resource`, `item` and `free_cast` commit/refund fields; a target `reaction`
branch is rejected. Native stopping reactions own their separate reaction policy.

---

## 2. S-115: Whole Pending Cast Cancellation

### Cancellation Rules
Reactive stopping spells or abilities declare a `cancellation_rule` object:
```json
{
  "target_scope": "whole_cast",
  "min_spell_level": 1,
  "max_spell_level": 3,
  "schools": ["evocation", "abjuration"],
  "sources": ["class", "feature"],
  "spell_ids": ["fixture:target_spell"],
  "contest": {
    "type": "save",
    "ability": "CON",
    "dc_from": "stopping_caster"
  }
}
```

- **Predicate Filtering**: `is_cast_matching_cancellation(cast, rule)` validates the incoming cast against minimum/maximum level, permitted schools, source types, and explicit spell IDs. Non-matching spells are preserved completely.
- **Contest Resolution**:
  - `type: "save"`: Target caster rolls against the stopping caster's save DC (e.g., 2024 Counterspell).
  - `type: "check"`: Stopping caster rolls ability check against DC (e.g., 10 + spell level).
  - `type: "none"`: Automatic cancellation without a roll.
- **Outcome**: A successful cancellation marks the target cast as interrupted (`interrupted = true`, `canceled = true`), settles the target cast payment per its declared interruption policy, and terminates resolution. Unrelated casts are untouched.

---

## 3. S-143: Stopping-Spell Success/Failure Cost Policy

Stopping reactions specify how their own costs are settled depending on whether the stop succeeded:
```json
{
  "stopping_cost_policy": {
    "on_success": {
      "slot": "commit",
      "reaction": "commit",
      "item": "consume_charge"
    },
    "on_failure": {
      "slot": "refund",
      "reaction": "commit",
      "item": "dispose_copy"
    }
  }
}
```

- `slot`: `"commit"` or `"refund"`
- `reaction`: `"commit"` or `"refund"`
- `item`: `"keep"`, `"consume_charge"`, or `"dispose_copy"` (e.g. single-use scroll)
- `free_cast`: `"commit"` or `"refund"`
- `resource`: `"commit"` or `"refund"`

A failed stopping attempt (e.g. Spell Breaker) refunds its own slot when declared, commits its reaction, and crucially **never repays or alters the original target spell**, which proceeds to execute against its targets.

---

## 4. S-116: One Recipient's Incoming Effect Negation

### Incoming Negation Rules
Negation excludes a qualifying target from incoming effects while preserving the cast and other recipients:
```json
{
  "incoming_negation_rule": {
    "target_scope": "recipient_effect",
    "min_spell_level": 1,
    "max_spell_level": 3,
    "schools": ["evocation"],
    "step_types": ["save", "damage"]
  }
}
```

Declared on:
1. Spells or individual spell steps (`step.incoming_negation_rule`)
2. Items equipped by recipient (`item.incoming_negation_rule`)
3. Passive class features on recipient (`effect.type: "incoming_spell_negation"`)
4. Explicit runtime decisions (`decisions.recipient_effect_negations[recipient_id]`)

### Execution
- In `SharedStepExecutor`, qualifying recipients are marked `{ "skipped": true, "negated": true, "reason": "recipient_effect_negated" }` and receive no damage, conditions, or saves.
- In `SpellResolver`, single-target negated spells return `{ "success": true, "hit": false, "damage": 0, "negated": true, "recipient_negated": true }`.
- Other targets in multi-target or area spells take full normal effect.
- Reflection and retargeting are separate operations outside this slice.

## Verified host and limits

The current review exercises real spell/payment/target controls and the native
Counterspell popup for slot, free-cast, point and exact item-charge target refunds.
Loaded reaction spells with `cancellation_rule` now enter the existing combat
reaction/payment controls without native ID registration. Actual custom success
and renamed, ID-filtered failure controls verify stopping settlement; exact
equipped-item disposal also has production resolver/payment proof. This bounded
window requires an observed component-bearing cast, line of sight, declared
range, an available Reaction and an exact current payment permission.
Stepped negation is per recipient and per matching step type; a protected primary
recipient cannot abort the other targets. Flat negation also blocks downstream
effects/riders. Malformed class/item ward rules refuse during loading.

The original build and acceptance reports overstate their button-control proof.
Use the superseding [review and repairs](../../.artifacts/planning/vocabulary-reports/batch-029-030-review.md)
for current evidence and limits. Legacy named magic-item activation paths and
standalone deferred resolver helpers are not newly certified by this review.
