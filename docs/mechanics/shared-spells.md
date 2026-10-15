# Author ordinary spells in JSON

Declare `"execution": "shared"` to use the ordinary spell pipeline without
adding an ID to a code list. Use a unique namespaced ID and put the JSON file
directly in `data/mods/spells/`. Add its ID to the intended class's
`spell_list_ids` using an approved class override as described in the
[modding guide](../modding_guide.md). Class membership and learning/preparation
still control who can cast it; shared execution does not grant ownership.

```json
{
  "id": "my_mod:ember",
  "name": "Ember",
  "execution": "shared",
  "level": 1,
  "casting_time": "action",
  "range": 12,
  "target": "single",
  "attack_type": "ranged_spell",
  "damage": "2d6",
  "damage_type": "fire",
  "upcast": {"damage_per_level": "1d6"}
}
```

Range and area geometry are five-foot hex counts. Delivery is automatic when
neither `save` nor an attack type is supplied. Use `save: "DEX"` (or another
ability) for saving-throw delivery, with optional `half_on_save: true`.
Attack types are `ranged_spell` and `melee_spell`. In simple spell records,
choose either `attack_type` or `save`. To compose mixed or sequential checks,
declare an explicit ordered `steps` array as described under
[ADR-0019](../decisions/0019-shared-ordered-execution-and-zero-hp-replacement.md).
`scaling` maps character-level strings to damage
formulas. `upcast` supports damage dice, healing dice or fixed healing/Temporary
HP increases and `additional_targets_per_level`.
Upcast dice are plain expressions such as `1d6`. Fixed healing increases require
an integer base healing value; choose either fixed or dice healing increases.
Healing and Temporary HP increases apply every additional slot level.

### Final attack/save outcome maps (S-098 BUILD)

Shared attack payloads and attack steps may declare
`damage_scale_by_outcome: {"hit": 1, "miss": 0.5}`. Shared save payloads and
save steps may instead declare `{"success": 0.5, "failure": 1}`. A declared
map must contain exactly both outcomes for its delivery type; scale values must
be finite numbers from 0 through 1. The map is selected after the host's final
hit/save result, including an accepted post-roll bonus or explicit outcome
override. Miss damage keeps `hit: false` in the receipt and uses the normal
typed-damage settlement path.

Outcome maps require an actual attack or save delivery. Automatic damage/effect
payloads cannot carry them. In an ordered spell, both damage and rider maps
belong to the individual attack/save step; outer spell maps are rejected before
payment rather than silently ignored. Uncanny Dodge halves the selected attack
damage scale, including zero, and the decision receipt retains the authored scale.

An effect may independently declare a complete Boolean `rider_by_outcome` map,
for example `{"hit": true, "miss": false}` for a hit-only condition, or
`{"success": false, "failure": true}` for a failed-save condition. The map
does not infer eligibility from the damage scale. Each settled target receipt
exposes `damage_scale_decision` (outcome, selected scale and rounding stage)
when an authored damage map is present and `rider_decisions` for mapped effects,
including false eligibility. Missing keys, extra/wrong-domain keys, unsupported
scales, and maps attached to unsupported step types are content errors and must
be rejected before cast costs. Unmapped ordinary payloads retain their prior
damage and rider behavior.

Damage uses the existing explicit floor rule: floor the rolled damage plus the
spell damage bonus multiplied by the selected outcome scale, then pass the
integer to typed damage settlement. Thus 5 damage at 0.5 becomes 2 before
resistance, immunity, interception, Temporary HP and HP loss. Flat delivery
uses `SpellAttackResolver` or `SpellSaveResolver`; ordered delivery uses those
same resolvers through `SharedStepExecutor`. Existing continuation retains the
same cast, roll and cost while the later damage choice settles. This slice does
not add recipient-specific Evasion/exemptions (S-099), new spell hosts, or maps
for standalone damage/effect steps.

Target selectors are `single`, `self`, `multi`, `area` and `cone`. Multi-target
spells declare `base_targets`. Area spells include an `area_selection` effect
with `shape: sphere` plus `radius`, or `shape: cone/cube` plus `size`.
Example: `{"type":"area_selection","shape":"sphere","radius":2}`.
Area and multi-target casts use the existing combat selection controls and
spend their slot/action once. A new ordinary spell does not need a new button.

| Effect | Fields and behavior |
| --- | --- |
| `heal` | `value` and optional `ability_bonus_from_caster`; respects healing prevention, caps at maximum HP and can heal unconscious living targets |
| `temporary_hp` | `value` and optional `ability_bonus_from_caster`; retains the greater existing amount |
| `grant_condition` | `condition`; uses the spell's required `duration_seconds`, source ownership and optional Concentration |
| `remove_condition` | `condition`; removes the modeled condition and its sources |
| `area_selection` | `shape` and positive `radius`/`size`; geometry, not an ongoing hazard |

Effects can be combined in their listed order. Use `on_spell_hit: true` for a
payload that requires a hit, or `on_failed_save: true` for a failed-save
payload. Ungated effects apply after a successful resolution, including a
successful saving throw. Unknown operations and effect fields are errors.

## Ordered steps: executable mixed checks and gating (ADR-0019)

Spells can declare an ordered `steps` array to execute multi-phase deliveries
with explicit gating, target scoping, and independent results:

```json
{
  "id": "my_mod:snare_and_strike",
  "name": "Snare and Strike",
  "execution": "shared",
  "level": 1,
  "casting_time": "action",
  "range": 6,
  "target": "single",
  "school": "transmutation",
  "steps": [
    {
      "id": "snare",
      "type": "save",
      "save": "STR",
      "effects": [
        {"type": "grant_condition", "condition": "restrained", "on_failed_save": true}
      ]
    },
    {
      "id": "impale",
      "type": "attack",
      "gate": "failed_save",
      "gate_step": "snare",
      "attack_type": "melee_spell",
      "damage": "2d8",
      "damage_type": "piercing"
    }
  ],
  "duration_seconds": 60
}
```

### Step specification
- Execution runtime: `SharedStepExecutor` is the unified ordered execution engine for stepped spells and creature event rules.
- `id`: Unique step identifier string.
- `type`: For spells: `attack`, `save`, `damage`, `effect`. (`replace_hp` is an event rule step type used in zero-HP replacement, and is invalid in spell definitions).
- Capability preflight refusal: Spells specifying unsupported step types (like `replace_hp`) or event-only save fields (`dc_base`, `dc_add_damage`, `save_ability`) are refused at preflight before any step execution, state mutation, or spell slot deduction.
- `target`: `target` (default, follows cast selection), `area` (uses area geometry), or `self`.
- `gate`: Execution condition based on prerequisite step: `always` (default), `hit`, `miss`, `failed_save`, `successful_save`.
- `gate_step`: ID or relative index of prerequisite step to check.
- **Results**: Execution returns top-level summaries (`hit`, `saved`, `damage`) and a `step_results` array containing each step's `step_id`, `type`, `target_mode`, `hit`, `saved`, `replaced`, `damage`, `skipped`, and detailed `target_outcomes`. Gating is evaluated per-actor, decoupling downstream steps from target iteration order.
- **Preserved damage & mixed summaries**: Attack steps followed by gated save steps retain initial attack damage when secondary saves succeed. Visible summaries accurately report `hit=true` when attacks hit, including when preceded by non-attack steps.
- **Area scoping & obstruction**: Area steps run independently across all eligible targets (`sphere`, `cone`, `cube`) with wall line-of-sight obstruction filtering (`blocks_sight`). Area steps missing spatial encounter context refuse preflight before mutation. Area damage rolls share a per-step raw roll context so targets in the same area share damage rolls without polluting other steps while save scaling applies individually.
- **Per-actor settlement**: In `SpellCastResults`, stepped spells execute once rather than re-running per outer target hex. Each affected actor settles damage, temporary HP, concentration CON saves, and enemy defeat triggers once.
- **Pre-roll choices**: Ordered spells suspend before each eligible attack or target save, and before each damage-triggered concentration save. Declining Portent on an earlier test leaves it available for a later test within its once-per-turn budget. Each choice belongs to the canonical actor and exact step; settlement retains prior damage, gates, shared area rolls and paid costs. Stale, replayed and wrong-kind callbacks refuse before resuming execution.
- **Suspension & resume**: Metamagic/damage choices (such as Empowered Spell reroll prompts) and reaction choices (such as Stroke of Luck or Bardic Inspiration on concentration saves) suspend at the exact actor and step. Resumption continues remaining area targets within the same step without dropping actors or redirecting secondary actor packets. Empowered Spell tracks remaining dice allowance across multiple rolls of the same cast (surfacing the remaining `max_dice` cap in the HUD popup on later steps) while committing 1 Sorcery Point once. Suspended failed-save condition grants apply once upon damage settlement. Owned damage and concentration requests are validated authoritatively before mutation; duplicate, copied, stale, or cross-cast callbacks refuse explicitly before state mutation, leaving legitimate requests available. Live Dictionary actors remain canonical live references without deep-copy detachment. Taking-damage concentration prompts suspend ordered execution with production HUD reaction dialogs before subsequent steps run. Accepting Stroke of Luck spends the feature and sets the d20 roll to 20 plus original modifier (which does not guarantee a save if 20 + modifier < DC); if declined or still failed, an available Bardic Inspiration die choice is prompted before concentration ends or subsequent steps execute. Accepting Bardic rolls the die once and adds it to the save total. A successful save maintains concentration and defenses (e.g. Shield of Faith AC 15), while declining or failing ends concentration immediately, exposing reduced defenses to subsequent steps in the same cast. This real two-choice HUD chain and two-process fresh-relaunch recovery (`scripts/validate_ordered_grant_fresh_relaunch.ps1`) are verified in production Godot 4.7 runs.

### Facts, predicates, and prior results (P1 authoring)

Ordered spell steps and their effects may add a `when` predicate. Spell-level
`effects` cannot use predicates or formula objects, even when the spell also
has ordered steps; put those effects inside the relevant step. Predicates
support nested `all`, `any`, and `not`, plus one comparison (`eq`, `ne`, `lt`,
`lte`, `gt`, `gte`) against one declared fact or one earlier damage result.
Numeric facts and damage results compare with numbers; boolean facts use
`eq`/`ne` and booleans; identity facts use `eq`/`ne` and strings. Unknown facts,
malformed types, forward/missing step IDs, non-damage result steps, and
mismatched damage types are rejected during definition validation.

At execution time, a declared fact or earlier result can still be unavailable
because the current cast or target does not carry it. That value is **unknown**,
not zero, false, or an empty identity. Unknown stays unknown through `not` and
does not independently grant eligibility. In a nested expression, `all` is
false if any child is false and otherwise stays unknown if a child is unknown;
`any` is true if a child is true and otherwise stays unknown if a child is
unknown. A final unknown condition does not run the guarded step or effect.
Present numeric zero remains a normal value and can match `eq: 0`.

The current fact vocabulary is deliberately small:

| Fact | Value |
| --- | --- |
| `actor.id`, `actor.level` | Caster identity and character level |
| `target.id`, `target.current_hp`, `target.max_hp` | Current step recipient |
| `target.is_alive`, `target.is_wounded` | Recipient's living and HP state |
| `target.is_source_owner` | Whether the recipient is the current source's owner/caster |
| `target.relationship` | Current `ally`/`enemy` relation to the caster from captured participant control lists; unavailable when not represented |
| `target.willingness` | Explicit `willing`/`unwilling` character preference; unknown stays unavailable |
| `target.charmed_by_actor`, `target.marked_by_actor` | Whether an exact source-owned charm/mark condition record names the bound caster as giver |
| `source.id`, `source.owner_id` | Current spell/source identity and owner identity |
| `action.id`, `action.invocation_id` | The action kind and runtime action invocation captured by the combat spell host (`magic` plus its transient invocation ID) |
| `item.definition_id`, `item.instance_id` | The exact validated Material component copy selected for this cast; unavailable when the cast has no owned copy |
| `spell.definition_id`, `spell.invocation_id` | Loaded spell definition ID and this cast's transient invocation ID |
| `source.definition_id`, `source.instance_id` | Spell definition that created the effect and exact effect-source instance; source instance is unavailable for instant/unmanaged spells without an effect record |

These names are explicitly scoped: `actor.id` reads the caster, `target.id`
reads the current step recipient, `spell.definition_id` is catalog identity,
and `spell.invocation_id` is one runtime cast. `source.instance_id` is never
filled from a spell definition ID. The older `source.id` keeps its compatibility
fallback to the spell ID; new content should use the explicit definition and
instance selectors when that distinction matters. Identity selectors accept
only string equality/inequality. An unavailable or wrong-kind value remains
unknown, including under `not`.

| Selected host | Bindings available | Values queried live versus captured |
| --- | --- | --- |
| Combat shared-spell step/effect host | Actor/caster; current step target; action kind and action invocation; spell definition and invocation; source definition, exact source instance when an effect record exists, and source owner; exact item definition/copy only for a validated material component | Actor and target fields read from their current Character/target records at predicate evaluation. Definition IDs, invocation IDs, validated item-copy IDs and effect-source IDs are captured for this cast and retained by its existing continuation. An already settled effect is not reevaluated. |
| Direct spell resolution without the CombatState cast host | Caster, current target, spell definition, and available effect-source metadata. Action/invocation/item facts without a captured cast host are unavailable. | Same live actor/target query policy; optional cast-host identities remain unavailable rather than inferred from caller-supplied decisions. |

The spell-only host does not invent an item. Item facts exist only when cast
validation selected and verified an actual owned Material copy; an absent or
invalid copy does not fall back to the item definition name or another entity's
ID. Consumed copies retain the already validated invocation receipt through the
cast continuation.

The development fixtures `sandbox:fact_window_neutral` and
`sandbox:fact_window_renamed` show different nested predicates over this same
allowlist. They put a nested predicate on an effect inside an ordered effect
step, so the decision controls that consequence rather than whole-spell
availability. The production `shared_fact_predicate_flow` drives both loaded
definitions through the real spell picker, command, target click and ordered
step settlement. It demonstrates numeric ordered/equality comparisons, string
and boolean comparisons, nested `all`/`any`/`not`, changed HP and source-owner
facts, present zero versus a false condition, and a mixed known-false/unknown
branch with a missing fact beneath `not`. That unknown condition skips only its
guarded effect; the valid cast still spends one slot and one Magic action.
Malformed unknown-fact and wrong-type definitions are disabled in the menu and
refused by the command before costs or effects. The scenario snapshots the
exact source pool and timed modifier across casts to confirm queries and
eligibility changes do not reacquire them or restart the deadline. Production
evidence, including bootstrap, 185-script parse, boot and the 11-assertion
scenario, is retained at
`.artifacts/tests/0a100c3d32f940e0963733ee0068fb4f/`. This proves only ordered
shared-spell step/effect eligibility through that combat host; whole-spell
availability, other hosts, broader world facts and all other V-001 requirements
remain open.

Fixed healing and Temporary HP accept integral JSON numbers as well as integer
text. SharedSpell normalizes decoded integral floats to integer text before
using the existing dice parser; `"value": 5` and `"value": "5"` both resolve
to five. Fractional numeric values remain invalid. Dice expressions, dictionary
formulas, healing prevention, maximum healing and ability bonuses retain their
existing rules. The earlier integral-number/zero-healing mismatch is repaired.

An earlier typed damage component is selected with:

```json
{"result":{"step":"burn","target":"cast_target","component":"fire","measure":"resolved"}}
```

`target` must be `same` (the actor being evaluated now) or `cast_target` (the
original selected spell target). This forces multi-target definitions to name
which actor's outcome they read. `component` is the damage type. `measure` is
`raw` (final amount passed to typed settlement, after roll/scaling and bonuses), `resolved` (after damage
mitigation/interception, before Temporary HP and HP loss), or `hp_loss` (actual
HP removed by that component's settlement, capped by the HP available before
settlement). A missing runtime outcome or failed calculation skips the affected
effect, including any caster ability bonus. A valid zero result still permits
its declared bonus. Malformed/unknown references are rejected before execution.

An effect can also explicitly sum one component/measure across the actual
target outcomes of one named earlier damage step:

```json
{"result_sum":{"step":"blast","component":"fire","measure":"hp_loss"}}
```

This counts each target once and keeps raw, resolved and actual HP loss
separate. A present earlier step with an empty outcome list sums to zero;
explicitly skipped target outcomes contribute zero. Missing or malformed step
results fail evaluation, and future/current-step or mismatched-component
references are rejected during definition validation. The selector works in
arithmetic and result predicates, so `gt: 0` can gate a single self-targeted
effect after an area step settles. It is only this explicit sum; it does not
add general reducers or implicit damage-type pooling. Neutral `sandbox:area_hp_tithe`
and renamed `sandbox:area_hp_tithe_renamed` fixtures show the data form.
Production acceptance exercised neutral Fire/12 and renamed Cold/10 definitions
through DataLoader and ordered casting. It proved raw/resolved/HP-loss measures
stay distinct, two actors with one catalog definition remain separate outcomes,
and the gated caster heal applies once after the damage step. A settled empty or
all-skipped result sums to zero; a missing or malformed prior result fails.
Invalid stage/component references refuse before spell-slot payment. A cast
resumed across three target-save choices retained completed outcomes and the
paid slot, then healed once; replaying the completed callback refused without
changing HP or cost. This is the checked VS-17 subset, not a general reducer or
cross-step result language.

## Exact prior-result receipts (S-034 BUILD)

Ordered steps can select one settled result with the existing `result` formula.
`step` is the exact earlier step ID. `target: "same"` means the runtime actor
currently being resolved by the consuming step; `target: "cast_target"` means
the exact actor captured as the cast target. Character references compare by
runtime object or stable character ID, and creature dictionaries compare by
their runtime `id` (or object identity when they have no ID). Shared definition
IDs and display names do not identify runtime targets.

Damage selectors keep the typed `component` field. A one-component damage step
gets the runtime identity `<step-id>:<damage-type>` unless it declares its own
`component_id`. A save step may carry an ordered `damage_components` list; each
entry can declare a unique `id`, otherwise its identity is its type's ordinal
such as `fire:1` or `fire:2`. Select an exact repeated component with
`component_id`:

```json
{"result":{"step":"impact","target":"same","component":"fire","component_id":"fire_a","measure":"absorbed"}}
```

A one-entry `damage_components` list keeps that entry's authored ID or type
ordinal too; it does not switch to the scalar step's identity.

Without `component_id`, a type-only selector works only when exactly one
component of that type is present for the selected target. If it matches more
than one component or target outcome, evaluation fails as ambiguous instead of
choosing the first. An absent, malformed, current/future-step, wrong-step or
wrong-component reference is unavailable or rejected during definition
validation; it does not become zero. A present zero remains a valid receipt.

Damage component measures are frozen at the target's own settlement:

| Measure | Receipt meaning |
|---|---|
| `raw` | Rolled/scaled amount presented to mitigation. |
| `resolved` | Amount left after resistance, immunity and ward absorption, before Temporary HP. |
| `prevented` | `max(0, raw - resolved)`, including mitigation and ward prevention before Temporary HP. |
| `absorbed` | Temporary HP actually consumed after mitigation/wards. |
| `hp_loss` | Target HP removed by this component, capped at current HP and read from the settlement receipt. |

Actual healing uses the same exact step/target form without a damage component:

```json
{"result":{"step":"mend","target":"same","measure":"healed"}}
```

`healed` reads the effect step's actual healing receipt after healing
suppression and the maximum-HP cap. It does not compare current HP before and
after a later effect. The damage values are stored on each component receipt;
the healing value is stored on the heal effect's target result. Both survive
the existing ordered-step continuation copies. `result_sum` remains the
accepted VS-17 form and continues to support only `raw`, `resolved`, and
`hp_loss`; this slice adds no reducer or mitigation operation.

Development fixtures `sandbox:receipt_probe` and `sandbox:receipt_probe_renamed`
exercise repeated same-type components, same-definition runtime actors,
resistance, immunity, Temporary HP and capped healing. This BUILD evidence is
not production acceptance; separate VALIDATE must exercise these selectors
through the real loaded controls and a later-choice continuation.

## Margin and settlement-HP gates (S-043 BUILD)

The ordered `result` selector also supports two non-component measures. Both
name one earlier step and one exact runtime recipient, so the selected
step/target pair is the roll or damage occurrence being read:

```json
{"result":{"step":"save","target":"same","measure":"margin"}}
{"result":{"step":"impact","target":"same","measure":"hp_after"}}
```

`margin` is the signed numeric difference **final numeric total minus DC/AC**.
Negative is below the DC/AC, positive is above, and equality is `0`. On an
ordinary save or attack, equality succeeds; a natural-1 attack can still miss
with a nonnegative numeric margin. `saved`/`hit` remains a separate final
outcome. S-092 explicit save outcomes preserve the rolled total and DC, so a
forced success or failure still has that roll's numeric margin even when the
boolean outcome disagrees. S-095 total/defending-AC edits are reflected in the
attack's numeric margin using its final adjusted total and AC. A no-roll or
automatic outcome has no numeric margin; the selector is unavailable and never
manufactures one from the forced boolean result. Pair `gate: "failed_save"`,
`gate: "successful_save"`, `gate: "hit"` or `gate: "miss"` with a margin
predicate when the branch requires both a final outcome and a numeric threshold.

`hp_after` is the target's HP copied from the completed attack/save/damage
settlement receipt. It includes a settled zero-damage result when that result
has an HP receipt. It is unavailable if the selected step has no damage
settlement receipt. It does not reread pre-damage HP or later current HP after
another heal/damage effect. A gated aftermath runs only once the selected step
has settled; an existing pending roll/damage choice keeps it suspended, and the
ordered continuation retains the result before evaluating later effects.
Missing, malformed, wrong-kind, current/future-step and wrong-target receipts
stay unavailable or fail definition preflight before cast payment/effects.

For example, pair the final `failed_save` gate with a margin threshold to
require both the final outcome and a numeric failure by at least five (`-5` or
lower). A different effect can check whether actual post-damage HP is at most
four:

```json
{"type":"effect","gate":"failed_save","gate_step":"save","effects":[{"type":"temporary_hp","value":2,"when":{"result":{"step":"save","target":"same","measure":"margin"},"lte":-5}}]}
{"type":"temporary_hp","value":3,"when":{"result":{"step":"impact","target":"same","measure":"hp_after"},"lte":4}}
```

Loaded development definitions `sandbox:margin_gate_neutral` and
`sandbox:settlement_hp_gate_renamed` use different thresholds and the two gate
forms. This remains ordered shared-spell step/effect behavior; it adds no
grouped all/any/count gates (S-044), and does not certify other resolution
hosts. BUILD checks are not production acceptance; separate VALIDATE must
exercise the real supported controls and inspect final receipts/costs.

Numeric values can use a result selector directly or a nested arithmetic
object. Supported operations are `add`, `subtract`, `multiply`, `floor_divide`,
`min`, and `max`; each has `left` and `right`. Dice strings remain supported as
leaf values. `floor_divide` requires a positive divisor: literal zero divisors
are rejected during definition validation; a divisor that evaluates to zero or
less at runtime skips the affected effect. For example, half a selected settled component rounded down is:

```json
{"op":"floor_divide","left":{"result":{"step":"burn","target":"cast_target","component":"fire","measure":"resolved"}},"right":2}
```

Ordered effect values can also read these caster/cast leaves:

| Formula leaf | Value |
| --- | --- |
| `{"caster_level": true}` | Caster's character level. |
| `{"caster_class_level": "wizard"}` | Caster's level in the named, known class. The class ID is required. The current `Character.get_class_level` query returns the character's level for their own class and 0 for another class; multiclass levels are not implemented. |
| `{"caster_proficiency_bonus": true}` | Caster's current proficiency bonus. |
| `{"caster_ability_modifier": "INT"}` | Caster's modifier for the explicitly named ability (`STR`, `DEX`, `CON`, `INT`, `WIS`, or `CHA`). |
| `{"selected_slot_level": true}` | Casting slot level held by this spell's cast context. It says nothing about whether a slot was paid. |

These leaves are numeric inputs to the existing arithmetic operations. For
example, this calculates at least 1 Temporary HP from the caster's Intelligence
modifier plus the selected slot level:

```json
{
  "op": "max",
  "left": 1,
  "right": {
    "op": "add",
    "left": { "caster_ability_modifier": "INT" },
    "right": { "selected_slot_level": true }
  }
}
```

The neutral `sandbox:slotward` example in
[`examples.json`](../../data/fixtures/shared_spells/spells/examples.json)
uses that value to grant Temporary HP. The slot level is captured when the
cast context is created from the selected cast option and is carried unchanged
through a pause/resume. It remains available for a free cast, so formulas must
not treat it as proof that a slot was paid. Character level, class level,
proficiency bonus, and ability modifiers are queried from the live caster when
an ordered effect evaluates its formula. If a cast pauses before that effect
runs, those character values are read when execution resumes; values used by
effects already settled before the pause are not recalculated.

Numeric formula objects can also select a fixed value from an authored
breakpoint table:

```json
{
  "op": "breakpoint_lookup",
  "input": { "caster_level": true },
  "breakpoints": [
    { "threshold": 1, "value": 2 },
    { "threshold": 3, "value": 4 },
    { "threshold": 9, "value": 6 }
  ]
}
```

Thresholds must be strictly increasing integers; each row contains one fixed
integer value. The lookup selects the greatest threshold not above its
deterministic input. An input below the first threshold fails the formula, and
an input above the last uses the last value. Its input cannot contain dice or
random formulas. Rows and formula nesting are bounded. This same operation is
used by numeric pool capacity and ordered spell effects; the neutral spell
consumer is `sandbox:breakpoint_lookup_probe` in
[`examples.json`](../../data/fixtures/shared_spells/spells/examples.json).

Unknown class IDs, invalid abilities, malformed selector objects, and
references with incompatible value types are rejected while the ordered spell
definition is validated, before cast costs or effects commit. This implements
only these caster/cast numeric leaves within the V-001/V-007 slice. Selector
objects are accepted only in ordered effect values; they are not added to
damage expressions or predicate operands. The bounded deterministic numeric
breakpoint lookup described above is checked by the production scenario in
[VS-16 and VS-17](../reviews/dnd-code-vocabulary-gap-checklist.md#verified-subsets-to-mark-off);
dice tables, choices, pool operations/recovery, event subscriptions,
multiclass progression, and broader vocabulary entries remain outside this
spell formula boundary. Constant integer expressions such as `3+2` are valid
lookup inputs; dice expressions remain invalid there. Actor-only formula
evaluation refuses nested result and selected-slot references that require an
active cast.

The neutral `sandbox:ember_echo` example in
[`examples.json`](../../data/fixtures/shared_spells/spells/examples.json)
deals Fire damage, then heals its source owner for half the resolved Fire
component if that owner is wounded. Its effect step also requires a positive
resolved component, showing a result predicate across steps. Renaming the
definition does not change its supported behavior.

This is not an arbitrary expression language: facts and operations are
allowlisted, general table lookups and actor selection are not supported, and result
references read one declared component from one earlier step.

`target.relationship` reads the current cast's player/monster participant lists
and compares the bound caster and recipient: same controlled side is `ally`,
opposite sides are `enemy`, and a missing or multiply-bound participant is
unavailable. Self is `ally`. This is a live query at each predicate evaluation;
it does not infer factions outside the current control lists.

`target.willingness` reads the recipient's explicit `willingness` value
(`willing` or `unwilling`). Character sheets expose Unknown/Willing/Unwilling,
and the value is stored with the Character. Old saves load as `unknown`; unknown
is unavailable, including under `not`, and cannot qualify consent. Authored
comparisons use `{"fact":"target.relationship","eq":"ally"}` and
`{"fact":"target.willingness","eq":"willing"}`. Both facts are live for
each evaluation. The authoritative cast, target and participant references
remain those captured by the host through a continuation.

`target.charmed_by_actor` and `target.marked_by_actor` check the bound caster's
character ID against the recipient's exact source-owned `condition_sources`
entry and matching `spell_effects` record (`charmed` or `hunters_mark`). A shared
definition ID or condition label by itself cannot identify a giver. These are
also live queries. Removing a source removes only its own condition grant and
effect record. The native Hunter's Mark helper still stores one caster-side
target ID and does not produce this source-owned record; it is outside these
queries. Charm behavior itself is not added here.

The remaining relationship boundary includes cross-actor control beyond the
current player/monster lists, willingness requests for NPCs without a represented
value, and native effects without per-source provenance. Formula
operations support only the caster/cast numeric leaves listed above; tables
remain unsupported. Result predicates compare component amounts; margin and
grouped child-outcome predicates remain unsupported. A bounded production check now covers the single-target Fire
component selectors, source-owner/wounded predicate, floor division, mitigation
outcomes and one genuine damage-choice continuation; see the [current
checkpoint](../operations/current.md). The later renamed/free-cast probe also
checks all five caster/cast leaf kinds and their pause/resume policy. Track
those completed boundaries as VS-01–05 in the
[vocabulary checklist](../reviews/dnd-code-vocabulary-gap-checklist.md#verified-subsets-to-mark-off);
the broader parent requirements remain open.

## Conditions, lifetime and other supported fields

Conditions currently supported by this contract are Blinded, Deafened,
Frightened, Poisoned, Prone, Restrained, Stunned, Paralyzed, Incapacitated, and
the existing `blessed`, `baned` and `shield_of_faith` benefits. Their lowercase
IDs are used in JSON. `duration_seconds` must be 1–86400; `concentration: true`
uses normal replacement/loss/expiry. `repeat_save: "CON"` (or another ability)
offers the existing target-end repeat save against the captured casting DC and
removes that source on success. Saved effects require their spell definition
to remain installed; missing content rejects loading before session mutation.

Values accept a nonnegative integer or bounded dice expression such as `2d8`,
`2d8+3`. `ability_bonus_from_caster` adds the caster's spellcasting
modifier separately. Existing costly/consumed component, sight, creature-type
and size restrictions remain checked by the cast pipeline.

Object damage requires `targets_objects: true`; `ignites_objects: true` opts
into ordinary ignition of eligible flammable objects. In room exploration,
the shared Spells controls offer single/self party effects and single-object
damage, with a target selector and Cast button. Area/multi-target spells use
combat controls; movement, summons and ongoing zones retain dedicated paths.

See [JSON examples](../../data/fixtures/shared_spells/spells/examples.json) and
[ADR-0017](../decisions/0017-shared-json-spell-execution.md). The
[schema](../json_schemas/shared_spell_schema.json) describes
record structure; the production loader additionally validates executable
combinations. To check the production paths on Windows:

```powershell
.\run_tests.ps1 -GodotPath 'C:\path\to\Godot.exe' -Suite all -Scenario shared_spell_flow
```

## Optional bonus on a failed shared-spell save

A passive class feature may own a numeric pool and offer one fixed bonus after
its owner rolls a failed save against a shared spell. For example,
`data/fixtures/shared_failed_save_numeric_bonus.json` defines a +5 Dexterity
bonus costing one use. The feature owns the exact pool; the save choice records
the natural roll, existing modifier, DC, chosen source and fixed bonus. Accepting
the choice pays once and recalculates success without another roll, before the
spell applies damage or riders. Declining leaves the original save and pool
unchanged. The amount, ability, and cost are authored data, not spell or class
ID behavior.

The pending choice is offered only when the real spell-cast host has the
interactive combat HUD chooser. Hosts without that chooser, including the
exploration/local-room path, resolve the ordinary save without offering this
optional feature. Production checks drove neutral Dexterity/+5 and renamed
Constitution/+7 definitions through the normal spell picker and chooser. The
owner's original natural d20, modifier and DC stayed visible; accepting could
convert a failure or leave it failed, and damage used the final outcome. One of
two eligible instances of the same Dexterity definition could be selected
explicitly. Decline, popup cancellation, natural success, wrong actor/target,
forged/empty/removed sources and replay did not charge a pool. A pre-roll Portent
choice and multi-target cast resumed without rolling or charging the cast twice;
combat teardown cleared settled request references. See the checked VS-18 subset
in the [vocabulary checklist](../reviews/dnd-code-vocabulary-gap-checklist.md#verified-subsets-to-mark-off).

Automatic no-roll failures, attacks, checks, death/concentration saves,
cross-actor help, dice bonuses, other host choosers and general reaction budgets
remain unsupported. This proves one fixed bonus after an owner's rolled failed
save against a shared spell, not general post-roll result editing.

The optional `payment_policy` on a `failed_save_numeric_bonus` effect accepts
`pay_on_choice` or `pay_on_converted_success`. Omission defaults to the existing
pay-on-choice behavior. Both policies require the exact source pool to cover the
authored cost when offered and again when the answer is settled. A converted
success under `pay_on_converted_success` pays once before damage/riders; if the
bonus leaves the save failed, the modified result remains but no use is spent.
If the exact source no longer has enough uses, settlement refuses before
applying the bonus or consequences. The choices are shown in the combat prompt.
Development fixtures are in
[`payment_policies.json`](../../data/fixtures/failed_save_bonus/classes/payment_policies.json);
production acceptance checked both policies through the real DataLoader, combat
chooser and resumed spell. It confirmed that a converted success pays once
before damage, an accepted still-failed result keeps full damage and pays zero,
and explicit or omitted pay-on-choice still charges on acceptance. Exact-source
funds are rechecked at offer and answer time; a stale zero balance refuses the
answer. This bounded policy subset is VS-19 in the
[vocabulary checklist](../reviews/dnd-code-vocabulary-gap-checklist.md#verified-subsets-to-mark-off);
the broader V-035 family remains open.

An owned passive feature may instead declare one
`failed_save_outcome_override` with an authored save `ability` and positive
exact-pool `cost`. It offers the same choice only after its owner actually rolls
a failed save against a shared spell. Accepting spends the authored cost from
that exact source once and
sets an explicit success outcome; it does not change the natural d20, numeric
total, modifier, or DC. Damage and riders then follow the successful-save path.
This operation cannot be combined with another same-ability failed-save
modification from that feature. Development fixtures in
[`outcome_overrides.json`](../../data/fixtures/failed_save_bonus/classes/outcome_overrides.json)
exercise neutral Dexterity/cost 1 and renamed Constitution/cost 2 data. It is
checked in production as the narrow VS-20 subset. The real combat chooser made
the final save successful without changing its natural roll, numeric total,
modifier, or captured DC; ordered damage mitigation and success/failure riders
used that result. A flat failed-save rider waited until the choice settled.
Declining or canceling retained the original failure and its consequences.
Already-successful saves, no-roll paralyzed failures, wrong ability/actor,
empty/stale/removed/forged sources, and old-completion replay did not grant a
success or charge a source. A pending fresh choice remained usable after an old
completion was replayed. The focused scenario also reuses the VS-18/19
multi-target, Portent and one-time cast-cost evidence; the acceptance log is
[`failed_save_numeric_bonus_flow`](../../.artifacts/tests/10c21f9d43cd48a0b7016eda80955c6e/)
and focused development checks are
[`978/0`](../../.artifacts/tests/7e616a3d05634cafb29e9cae10a3f05b/).
The legacy save-success form remains supported for the accepted VS-20 route.
S-092 adds a generic owned outcome operation for rolled shared spell saves and
actual weapon/shared-spell attacks. A passive feature declares:

```json
{
  "type": "roll_outcome_override",
  "domains": ["weapon_attack", "shared_spell_attack"],
  "outcomes": ["hit", "miss"],
  "stage": "provisional_outcome",
  "cost": 1
}
```

For saves, use `domains: ["shared_spell_save"]`, `outcomes` containing
`"success"` and/or `"failure"`, `stage: "after_roll_before_consequences"`,
and the matching `ability`. The feature must own a numeric pool. The loaded
definition rejects attack/save outcome mismatches, wrong stages, extra fields,
missing pools and invalid costs. The old `failed_save_outcome_override` is
still read as a success-only shared-spell save option.

The choice appears only when the exact source is owned, affordable, matches the
captured attack domain or save ability, and offers the opposite of the current
rolled result. Weapon attacks use CombatState's existing attack chooser;
single-target shared-spell attacks and shared-spell saves use the existing
CombatHUD attack/save chooser and continuation. Saves offered here have a real
d20 result and belong to a Character target. Automatic failures, willing
no-save targets, Contact Patron, Careful Spell success, Death Saves,
concentration and non-shared spell saves do not use this choice.

The outcome override is recorded separately with its exact source instance,
source owner, feature and pool definition, domain, stage and cost payment.
Natural d20, effective mode, modifiers, total and the captured AC/DC remain
unchanged; an override never becomes a natural 20 or a numeric bonus. It takes
precedence over the d20 comparison and ordinary post-roll attack result after
the existing Shield and Peerless Aim handling.
Those native stages see the numeric roll's outcome, so a selected forced miss
cannot waste an unused Peerless Aim charge. A source may declare only one
modification for each attack domain: combining numeric/die bonuses with an
outcome override, or duplicating an override, refuses content validation in
either authoring order. Different domains may still use different operations.
Natural 20 remains critical only when the final attack hits; forcing a hit on a
natural 1 does not create a critical by itself, though a separate existing
critical condition can still apply. Forcing a miss on a natural 20 suppresses
critical damage. Save natural 1 and 20 keep the save's ordinary total-vs-DC
rules, and the explicit outcome wins that comparison without changing the
natural or total. Original spell/action costs and earlier ordered steps remain
settled once; save riders, attack damage and hit/miss-gated steps wait for the
final outcome. Existing later damage choices retain the override receipt.

This is limited to the listed rolled attack/save routes. No-roll outcomes,
canceled Death Saves, token replacement, other save hosts, cross-actor choices
and catalog-wide support remain later work. The wider V-013 family remains
open.

Post-roll suspension preserves an already-spent Bardic Inspiration bonus and
the original save DC. Flat effects wait for the final save outcome. Ordered
steps return the save choice before recording consequences; if its answer
creates a deferred Empowered damage choice, the original continuation moves
to that request and advances only after damage settlement. No save reroll,
source repayment or early rider is introduced by either resume.

An owned passive `weapon_attack_numeric_bonus` may also name the
`shared_spell_attack` domain alongside `weapon_attack`. On an actually rolled
shared-spell attack that provisionally misses, the spell uses the same exact
source chooser and fixed-bonus settlement as a weapon attack. Natural 1 and
already-hit results do not offer it. The captured spell attack roll, pre-roll
choices and slot remain settled once; flat damage/effects wait for the answer.
Ordered attacks keep their target/step continuation, so hit or miss riders are
applied only after the bonus is accepted or declined, and any later damage or
concentration choice resumes from that same continuation. The selected source
uses its authored payment policy after final hit resolution. This remains a
combat chooser path; noninteractive shared-spell callers keep ordinary attack
resolution.

The same three owned post-roll choice paths also accept an optional authored
`die_size` instead of `amount`: a rolled failed save, a normal player weapon
Attack/Extra Attack, or a shared-spell attack that provisionally missed. The
definition must provide exactly one of those fields and use a currently
supported die size. Availability and opening/querying a chooser do not roll;
the selected die is rolled only after the exact source and its current pool
have been revalidated at acceptance. The one result is retained through any
subsequent damage/concentration continuation, and settlement replay cannot
roll it again. It changes only the captured total; the original natural roll,
modifier, DC/AC and critical status are kept. The existing payment policy is
unchanged: `pay_on_choice` spends on acceptance, while
`pay_on_converted_success` spends only if the final save succeeds or attack
hits. For example, `post_roll_die_bonuses.json` defines neutral d6/cost 1 and
renamed d8/cost 2 versions for all three supported domains. The rolled-save,
normal player weapon Attack/Extra Attack, and real combat flat/ordered shared-
spell attack chooser paths are production checked in [VS-23](../reviews/dnd-code-vocabulary-gap-checklist.md#checked-subsets-and-bounded-implementation).
Other save/attack hosts and noninteractive callers keep their ordinary behavior
and remain outside this checked subset.

In the real spell chooser, a selected source that becomes unavailable or changes
before answering rolls/spends nothing. The host settles the original captured
roll as a decline through the same validated request, applies its ordinary
consequences once and clears the pending choice. Invalid actors, ended encounters
and already-settled requests still refuse; this fallback cannot revive a stale
request or substitute a new roll. The weapon-only native Stroke helper likewise
rejects a canonical shared-spell request before using its native resource.

An owned passive feature can also adjust a qualifying provisional hit's attack
total downward or raise the defending AC for this occurrence. Both operations
use the attacker's own source and numeric pool, in the normal player weapon
Attack/Extra Attack chooser or the interactive single-target shared-spell
attack chooser. The attacker's exact source must still be present, owned and
affordable when the answer is accepted; another actor's source or budget is
never queried. These are not general defensive reactions or cross-actor
interventions.

The supported effect shapes are:

```json
{
  "type": "attack_total_adjustment",
  "amount": 6,
  "cost": 1,
  "domains": ["weapon_attack", "shared_spell_attack"],
  "trigger": "provisional_hit",
  "payment_policy": "pay_on_choice"
}
```

```json
{
  "type": "defending_ac_adjustment",
  "amount": 2,
  "cost": 2,
  "domains": ["weapon_attack", "shared_spell_attack"],
  "trigger": "provisional_hit",
  "payment_policy": "pay_on_converted_success"
}
```

Amounts and pool costs are positive integers from 1 to 20 and 1 to 100
respectively. The source feature must be passive and own a valid numeric pool;
each source may declare only one attack modification per domain. The menu is
available after a real d20 has provisionally hit, before damage or hit-only
riders. Natural 1 misses and natural 20 critical hits do not open this menu.
Subtracting from a normal hit may make it miss; raising AC may leave a hit or
make it miss. `pay_on_choice` spends the declared cost after acceptance;
`pay_on_converted_success` spends only if the final attack still hits. A
decline spends nothing. A stale, replayed, depleted, removed, changed or
wrong-owner selection refuses without another roll or payment.

The adjustment receipt records its exact source instance, feature and pool,
attacker owner, domain, occurrence-only scope, policy and paid cost, along with
the original and final natural, modifier, total, attack profile and AC, final
hit and critical state. A total adjustment changes only the captured total and
its display modifier. An AC adjustment changes only the local AC comparison for
that attack; it never writes the defender's AC. Natural-roll and existing
critical boundaries remain intact, and attack/action/slot payment stays with
the original action. Final damage and hit-only riders wait until adjustment
settlement. Ordered attacks carry the receipt through a later damage choice.

This contract covers only normal player weapon Attacks/Extra Attacks and the
interactive single-target shared-spell attack host. No-roll outcomes, Death
Saves, other actor-owned attacks, noninteractive shared-spell callers, and
general cross-actor intervention are not offered by these operations.

### Shared spell attack resolution windows (S-041)

Shared spell attacks expose a `resolution_windows` receipt from the actual attack
roll and damage settlement. The supported host is a single-target shared spell
attack (`attack_type: ranged_spell` or `melee_spell`) resolved by
`SpellAttackResolver`; this includes the attack step in an ordered shared spell.
Noninteractive callers get the same receipt. A combat attack-bonus choice pauses
after `provisional_outcome`; an existing deferred damage choice pauses after
`pre_damage`. Resuming either request keeps the same `resolution_occurrence_id`,
original roll and source bindings. No spell reroll is used to rebuild a receipt.

Each entry has `window`, `occurrence_id`, `kind`, and the available nonempty
bindings among `actor_id`, `target_id`, `action_id`, `action_invocation_id`,
`spell_definition_id`, `spell_invocation_id`, `source_definition_id`,
`source_instance_id`, and `source_owner_id`. An ordinary spell cast has the
spell's exact definition and caster as source/owner; `source_instance_id` is
present only when the cast already has an owned source instance. The ordered
windows and additional fields are:

| Window | Added fields available at that point |
| --- | --- |
| `before_roll` | None; no d20 facts exist yet. |
| `after_natural` | `roll_natural`, `roll_modifier`, `roll_total`. |
| `provisional_outcome` | Roll fields, `target_ac`, `provisional_hit`, `provisional_critical`; later choices may still change the result. |
| `pre_damage` | Roll fields, `target_ac`, `final_hit`, `critical`, and `attack_adjustment` when a selected S-095 adjustment settles; no damage receipt exists yet. A miss gets this for declared miss damage or a settled attack adjustment whose final receipt must remain inspectable. |
| `post_damage` | The pre-damage fields plus `damage_occurrence_id`, `damage_type`, `damage_raw`, `damage_resolved`, and `damage_hp_loss` from the existing primary damage component. |

`available_fields` on each entry lists only facts present in that entry. The
`SharedStepExecutor` bounded `when` predicate can read the current entry using
`resolution.<field>` facts, for example
`{"all":[{"fact":"resolution.window","eq":"post_damage"},{"fact":"resolution.damage_hp_loss","gt":0}]}`.
Identity/type/window selectors require string equality; the damage occurrence
ID is numeric like the existing WardRules receipt, roll and damage amounts are
numeric, and hit/critical selectors are booleans. An absent field is unknown and
does not qualify, including under `not`. Once final, the entries are also
returned in `resolution_windows` in the order above. Post-damage currently
exposes only existing raw, resolved and HP-loss measures; prevention, absorption
and other measures remain S-034.

These receipts do not create a general subscription or an action-replay path.
The ordered adapter binds the current child attack's receipt before its effects
and following effect steps read `resolution.*`, including after attack and
damage choices. Only that receipt's recipient qualifies; another actor cannot
inherit it. A new attack replaces the previous occurrence, including on a miss;
a save or standalone damage step clears the attack-window context. Unavailable
future fields remain unknown. Damage settlement stays in the existing owner.
Numeric attack bonuses are offered for supported provisional misses, while
explicit hit/miss choices use the separate S-092 contract above. An ordinary final miss
does not create a damage choice or charge a damage-only source. S-042 cast/source
end windows, other roll domains, roll-mode edits and defensive edits remain
outside this subset. S-092 separately supports the declared explicit outcomes.
