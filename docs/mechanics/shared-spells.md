# Author ordinary spells in JSON

Batch L adds a bounded `grant_source_benefits` self-cast host for fixed AC and walking-speed additions; see [source carriers](source-benefit-carriers.md) for syntax, independent-review status and limits.

`bind_tether` supports several Character-anchored recipients under one cast;
see [tethers](tethers.md) for capacity, exact relation selection and cleanup.

Declare `"execution": "shared"` to use the ordinary spell pipeline without
adding an ID to a code list. Use a unique namespaced ID and put the JSON file
directly in `data/mods/spells/`. Add its ID to the intended class's
`spell_list_ids` using an approved class override as described in the
[modding guide](../modding_guide.md). Class membership and learning/preparation
still control who can cast it; shared execution does not grant ownership.

## First catalog conversion batch

Bless, Bane and Mass Healing Word use shared definitions in
`data/core/spells/conversion_batch_001.json`, with manifest-approved precedence.
The [ten-candidate boundary](../planning/vocabulary-slices.md#conversion-batch-001)
owns acceptance and the content still blocked; this does not convert the rest
of their native spell families.

Shared creature targeting admits downed Characters through the existing target
eligibility query, while dead creatures remain outside ordinary spell targets.
Creature-type filters still apply. Sight-required casts inspect the actual
downed recipient, including its invisibility, rather than an empty space.
Multi-recipient healing rechecks distinct recipients, range and the slot's
target cap before paying. Selecting an already selected target finishes a
smaller selection; Cancel spends nothing.

Bless/Bane retain the existing source-owned `blessed`/`baned` conditions and
concentration lifetime. Overlapping copies retain independent sources without
adding extra bonus/penalty dice. Bless's existing saving-throw bonus also reaches
rolled Death Saves; natural-result consequences remain authoritative. Indomitable
checks the modified failure and applies only the final roll's modifier dice.
Automatic Death Save outcomes and broader roll-choice support are unchanged.
Existing saved condition/source records need no conversion.

## Ordinary authoring example

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

### Damage and healing dice edits (Batch 025 build)

Shared spells and ordered attack/save/damage steps may declare bounded
`damage_dice_policy`:

```json
"damage_dice_policy": {"remove": 1, "maximize": 1, "sides": 6}
```

The runtime skips `remove` eligible positive dice before rolling, then sets up
to `maximize` eligible dice to their maximum without RNG. `sides` optionally
limits both operations to one supported die size. Constants and negative dice
terms are excluded. The roll receipt records the numbers removed and maximized;
critical repetitions apply the same policy to each repeated damage roll by
default. Set `"apply_to_critical": false` to spend the edit count on the base
damage roll only; added critical dice roll normally and do not consume that
count. The receipt counts edits actually applied.
Typed save components share one removal/maximization quantity in authored
component order; ineligible sizes do not consume it. Ordered attack/save/damage
steps use their own declared policies, without inheriting top-level policies.
Healing and Temporary HP effects may use the same object as `dice_policy`.
Beacon of Hope maximizes only the remaining healing dice after removal.

Healing effects may also declare a deterministic `reroll_policy`:

```json
"reroll_policy": {
  "count": 1,
  "selection": "lowest",
  "sides": 6,
  "keep": "new",
  "cost": {"source_instance_id": "feature:healing-reroll", "amount": 1}
}
```

The runtime selects up to `count` retained positive dice of the optional `sides`
size, choosing lowest or highest faces in stable formula order, then rerolls each
once. `keep` is `new` (default), `higher`, or `lower`. An optional cost spends
the stated quantity from that exact caster-owned source when enough eligible
dice exist; if the source cannot pay, the reroll is skipped and the original
healing stands. The result records original/new faces, kept face, exact source,
requested quantity and the pool payment/refusal receipt (including captured
die identities when that pool holds dice).
Retained original faces stay selectable under `higher`/`lower`; discarded faces,
including extra Heroic Inspiration rolls, retain one matching kept flag per face.
This policy runs once for each authored heal effect application. Temporary HP
effects cannot declare it. This is an automatic authored selection rule; it does
not add a new chooser or alter the existing Empowered Spell damage chooser.
If Beacon of Hope already maximizes the target's healing, the reroll policy is
skipped without spending its cost.

Shared damage can also declare a rational `damage_result_multiplier`, and heal
or Temporary HP effects can declare `result_multiplier`:

```json
"damage_result_multiplier": {"numerator": 1, "denominator": 2, "rounding": "floor"}
```

The multiplier runs after the ordinary rolled total, bonus and outcome scale,
and before typed damage prevention/resistance. Its receipt keeps numerator,
denominator and rounding explicit. Healing and Temporary HP apply their
multiplier to numeric or formula values after adding the caster bonus, with
Beacon maximization before that bonus. Supported rounding is `floor`, `ceil` or
`nearest`; malformed policies refuse during shared content validation. Damage
multiplier objects may set `"exclude_critical": true`; the critical result keeps
its unmultiplied amount and the receipt states that the multiplier was excluded.
This applies to every typed component, including additional packets; their raw
and prevented damage history uses the same amounts as settlement.

### Linked damage split and redirection (Batch 031; VS-107/108 accepted)

An ordinary shared spell can carry an incoming-damage link with one
`grant_damage_link` effect:

```json
{
  "effects": [{
    "type": "grant_damage_link",
    "policy": {
      "operation": "split",
      "share_percent": 50,
      "rounding": "floor",
      "fallback": "keep_original",
      "require_willing": true
    }
  }],
  "duration_seconds": 60,
  "concentration": true
}
```

The grant belongs to the exact spell source and names both its actual recipient
and caster. `operation` is `split` or `redirect`; the declared percentage is
transferred from each already-scaled damage occurrence. A split must leave a
positive share with the original recipient (1–99%). A redirect accepts 1–100%.
Rounding is `floor` or `ceil`, applied only to the transferred share. `fallback`
is `keep_original` or `refuse`; willingness is checked on the linked actor when
`require_willing` is true. Only an explicit source selection can choose among
overlapping links. If that selected source or recipient is stale or ineligible,
the fallback applies; the engine does not silently switch to a sibling. A
declined choice keeps the original recipient under `keep_original`.

The stage is after attack/save outcome scaling and authored damage reductions,
and before recipient mitigation. Each typed component is split independently.
The same occurrence, source identity, and cause continue through each receipt;
the attack, riders, and parent slot/action are not replayed. Each recipient then
settles Resilient Sphere prevention, resistance, wards, immunity, Temporary HP,
HP loss, and applicable concentration or zero-HP consequences once, in the
existing project resolver order. Receipts expose the parent occurrence and a
separate raw, prevented, resolved, ward/Temporary HP absorbed, and HP-loss
receipt for each recipient. The split-stage amounts conserve the post-reduction
damage; later defenses can make the final losses differ.

Flat and ordered shared spells, plus ordinary weapon attacks, use the shared
settlement boundary. Link records are source-owned save data and are checked
against their loaded shared-spell definition on restore. Pending selections and
damage receipts are transient. This build does not link an actor that is outside
the live party/combat roster, does not provide creature-side authored link
grants, and does not add link behavior to older named spell handlers.

Selected damage-die rerolls keep using the existing Empowered Spell chooser:
the owner selects from the actual retained positive dice, each chosen die is
rerolled once, its old face remains in the receipt, and unselected siblings do
not change. This build does not add a separate general reroll chooser or
catalog conversion. Exact-source weapon-rider payment waivers continue to use
their existing active-grant and parent-action checks; they waive only that
rider's pool charge, leaving the parent Action/Reaction and other riders'
payments intact.

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
same cast, roll and cost while the later damage choice settles. S-099 separately
adds exact per-recipient save maps and an authored flat-spell damage exemption
choice. Neither changes other recipients or the independent rider policy. New
spell hosts and maps for standalone damage/effect steps remain outside this
subset.

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

An eligible flat, single-target numeric save may declare
`save_exit_placement` to require a legal exit before save consequences settle.
Combat uses its live encounter entities; local-room casting binds the current
party positions, room plane and room grid, then asks for a highlighted room-map
cell or cancellation. Both hosts resume the captured roll/total/DC through the
same resolver continuation and recheck live occupancy before applying damage or
failed-save effects. The local-room host rejects room/actor plane mismatches.
Other save shapes remain outside this placement policy.

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
| `target.actor_hex_distance_feet` | Live axial hex distance from the bound caster's current battlefield position to the current target, in 5-foot steps |
| `target.source_hex_distance_feet` | Live axial hex distance from the exact located source instance's current area center to the current target, in 5-foot steps |
| `target.damage_{raw,prevented,absorbed,resolved,hp_loss}_since_combat_turn` | Numeric finalized damage total for this target, exact caster actor and current cast damage-source instance since the active initiative turn began |
| `target.damage_{raw,prevented,absorbed,resolved,hp_loss}_since_owner_turn` | Same exact source/target measures since this target's most recent actual initiative turn began; unavailable until that target has a turn boundary |
| `target.damage_{raw,prevented,absorbed,resolved,hp_loss}_within_last_minute` | Same exact source/target measure over campaign timestamps with age `< 60` seconds; equality at 60 expires |
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
| Combat shared-spell step/effect host | Actor/caster; current step target; action kind and action invocation; spell definition and invocation; source definition, exact source instance when an effect record exists, and source owner; exact item definition/copy only for a validated material component; current `SpellCastContext` participant positions and exact active spell-zone records | Actor distance resolves the exact live Character/monster object in the battlefield arrays. Source distance resolves only `source.instance_id` in the current `CombatSpellZones.active_spell_zones` map and uses that zone's `center`. Both are queried again when the predicate runs. Definition IDs, invocation IDs, validated item-copy IDs and effect-source IDs remain captured for the cast. An already settled effect is not reevaluated. |
| Direct spell resolution without the CombatState cast host | Caster, current target, spell definition, and available effect-source metadata. Action/invocation/item facts without a captured cast host are unavailable. | Distance can use a Character's current room-owned party position; battlefield participant and located-zone positions are unavailable without the live cast host. Optional cast-host identities remain unavailable rather than inferred from caller-supplied decisions. |

The spell-only host does not invent an item. Item facts exist only when cast
validation selected and verified an actual owned Material copy; an absent or
invalid copy does not fall back to the item definition name or another entity's
ID. Consumed copies retain the already validated invocation receipt through the
cast continuation.

### Damage history (S-031)

Damage-history facts compare numeric quantities against the actual caster's
stable actor ID and this cast's exact damage-source instance ID. A managed
effect uses its saved source instance; an instant cast uses its captured
invocation ID (or a unique caster cast serial when no host is present). Two
casters or two source instances never share a bucket. Turn facts read bounded
per-encounter totals: the combat-turn baseline snapshots at each actual
initiative turn; the owner-turn baseline snapshots when that exact target
starts its own turn. Encounter reset drops these aggregates. Menu queries,
canceled commands, previews and scene changes do not touch either baseline.

Campaign-time facts keep at most 128 target/source/second aggregates per
Character. A fresh settlement at the same second and exact source is combined.
An entry is eligible only when `0 <= now - at_seconds < 60`; at exactly 60
seconds it is expired. A large campaign-time jump neither creates a receipt nor
restarts its timestamp. Character DTOs carry target ID, causal actor ID, exact
source instance, absolute campaign second and each measure. Checkpoint
preflight rejects malformed identities, measures, timestamps and oversized
history before session replacement. Old schema-2 Characters with no history
field remain valid. This writes only allowed overworld/dungeon-entry checkpoints;
active combat stays unsaveable.

| Measure | Damage-history meaning |
|---|---|
| `raw` | Nonnegative amount presented to typed settlement, before reductions |
| `prevented` | `max(0, raw - resolved)`; includes mitigation, immunity and ward prevention before Temporary HP |
| `absorbed` | Ward amount plus Temporary HP actually consumed; this intentionally overlaps `prevented` for ward absorption |
| `resolved` | Amount remaining after resistance, immunity and ward absorption, before Temporary HP |
| `hp_loss` | Actual HP removed, capped to current HP and read from the final settlement receipt |

The current bounded history requires a Character target and an exact Character
causal actor. Dictionary-only combatants and damage with no actor source do not
produce these actor-source facts. When a Character's 128-entry window is full,
the oldest entry is dropped. These limits keep the history bounded; they do not
certify a general combat journal or arbitrary duration selector.

### Explicit settled-result reducers (S-035)

An ordered formula may select prior damage receipts with
`{"result_reduce":{"reducer":"sum|min|max","steps":["step_id"],"targets":"all|same|cast_target","component":"fire","component_id":"optional-id","measure":"raw|prevented|absorbed|resolved|hp_loss","empty":"zero|unavailable"}}`.
The reducer and empty policy are paired: `sum` requires `empty: "zero"`; `min`
and `max` require `empty: "unavailable"`. `steps` is an explicit, unique list
of up to 20 earlier settled attack/save/damage steps. `all` selects each distinct
target outcome for those steps once; `same` selects the current effect target;
`cast_target` selects the captured cast target. Each value is the named typed
component's already-settled integer measure. The reducer combines those values
once in listed step order; it does not round intermediate receipts or infer
other components. Put integer rounding in the surrounding formula (for example,
`floor_divide` after `sum`).

An empty selection returns 0 only for `sum`. Empty `min`/`max`, missing or
unfinished steps, malformed receipts and missing component measures are
unavailable; they do not fabricate zero. A known component with a settled value
of 0 remains a value for all three reducers. Repeated same-type components must
name an exact `component_id`; ambiguous or forward selectors are rejected before
costs where the authored step structure makes that knowable. This operation
does not add grouped all/any/count behavior or a general collection language.

A resolved miss or successful save with explicit zero damage and no component
receipts is a known empty damage selection. A malformed or absent measure on
an existing component remains unavailable. Reducer `absorbed` preserves the
prior-result measure below (Temporary HP consumed); damage-history `absorbed`
separately includes ward absorption. Component-list payloads declare `id`, and
the selector uses `component_id` to choose it.

`sandbox:result_reduce_neutral` and `sandbox:result_reduce_renamed` exercise
different loaded sums with max/min. `result_reducer_flow` drives each through
the real picker and aftermath with distinct integer totals, exact HP/THP
receipts, one slot and one turn action each. Detailed current-source production
evidence is retained in the S-035 validation report.
The independent Batch E area control additionally selects two same-definition
combatants across two steps with repeated fire components. The exact `ember`
component produces sum 11 (rounded once to 5), min 2 and max 5, excluding the
19-point fire component. See the
[Batch E review](../../.artifacts/planning/vocabulary-reports/batch-E-review.md).

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

### Located distance predicates (S-027)

The authored numeric facts `target.actor_hex_distance_feet` and
`target.source_hex_distance_feet` state both the metric and units. Positions are
the existing pointy-top axial hex coordinates; one hex step is 5 feet and the
distance is `HexUtils.get_distance * 5`. A range boundary is explicit in the
comparison itself: `lte: 10` includes exactly 10 feet, while `lt: 10` does not.
This is center-to-center hex distance; it does not calculate elevation,
footprint/edge distance, path cost, obstruction or line of sight.

The actor-relative fact measures the bound caster to the current step target.
Both must be the exact live Character/monster participant objects in the active
`SpellCastContext`; reused IDs or copied projections do not resolve. Outside an
encounter, the current active party Character may resolve through `LocalRoomRules`'
party-owned `party_positions` map. A copied Character with the same ID cannot use
that position. A missing combat participant never falls back to a room position.
Other unrepresented actors have no distance fact.

The source-relative fact measures the current target to the center of the exact
`source.instance_id` entry in the live combat area's `active_spell_zones` map.
It cannot resolve a spell/zone definition ID, source owner, bearer position, or
another instance sharing that definition. Moving the bearer changes the target
endpoint only when that bearer is the current target; moving the zone changes the
source endpoint. Moving the zone's caster/bearer does not relocate its center.
Removing the exact zone,
missing either position, or lacking this combat host makes the value unavailable,
including under `not`. Room objects and arbitrary effect records are not located
sources for this first slice.

These are live predicates: they read the current endpoints when the ordered
effect's `when` runs. A decision already settled in its declared step is not
reopened by later movement. No move, source creation/removal, aura membership
update, or visibility/line-of-sight action occurs as a side effect of reading
distance. Loaded development consumers and focused checks are in
`data/fixtures/shared_spells/spells/distance.json` and
`SharedSpellChecks._distance_predicate_checks`. Production evidence and the exact
accepted host limits are recorded in the [Batch D review](../../.artifacts/planning/vocabulary-reports/batch-D-review.md).
The source-relative fixture receives an exact existing zone source through the
internal cast adapter; this adds no generic source picker or authorable lookup by
definition/name. Instant spells without a located source remain unavailable.

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
checkpoint](README.md). The later renamed/free-cast probe also
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
uses the captured casting DC. By default it repeats at the end of each affected
creature's turn and removes that source on success. Batch 026 adds optional
schedule, staged-condition and DC-history fields:

```json
"repeat_save": "WIS",
"repeat_save_schedule": "elapsed_seconds",
"repeat_save_interval_seconds": 60,
"repeat_save_stages": [
  {"condition": "restrained", "successes_required": 2, "minimum_margin": 2,
   "on_failure": "stay", "reset_successes_on_failure": true},
  {"condition": "paralyzed", "successes_required": 1, "on_failure": "end"}
],
"repeat_save_dc_progression": {
  "increase_on": "failure", "amount": 1, "maximum": 5,
  "reset_on_success": true
}
```

Use `target_turn_end` or `elapsed_seconds`; the elapsed schedule requires an
interval from 1 to 86400 seconds. Stage 1 must match the condition granted in
`effects`. A qualifying success has `total - current DC >= minimum_margin`;
the configured number advances the source to the next stage, and the final
stage ends that source. A failed save follows `on_failure` (`stay`, `advance`
or `end`); `reset_successes_on_failure` optionally clears that stage's count.
DC increases apply to later attempts after the current save. An authored
successful-save reset clears the increase. Attempt count, deadline, DC
adjustment, stage cursor and original save purpose/context live on the exact
effect record and are validated against the loaded definition before restore.
Elapsed-time advancement visits deadlines and effect expirations in time order
across all represented targets. Expiry wins an equal-time tie; no save runs at
or after that source's expiration. The final campaign clock is preserved.
Definitions declaring scheduling, stages or DC progression require complete
saved history, including default-valued context/counters. Old unstaged
default-turn definitions may still restore their older records without history.
All stage conditions must be supported condition IDs. This is generic
shared-spell behavior; no catalog spell is converted by Batch 026.

The builder implementation and retained checks are pending independent Batch
026 review. Effects on monsters still end with the encounter; only party
Character state participates in campaign-save recovery. A missing spell
definition rejects saved effects before session mutation.

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
`pay_on_choice`, `pay_on_converted_success`, `pay_on_final_success` or
`pay_on_final_failure`. Omission defaults to the existing pay-on-choice behavior.
All policies require the exact source pool to cover the
authored cost when offered and again when the answer is settled. A converted
success under `pay_on_converted_success` pays once before damage/riders; if the
bonus leaves the save failed, the modified result remains but no use is spent.
If the exact source no longer has enough uses, settlement refuses before
applying the bonus or consequences. The choices are shown in the combat prompt.
Final-result predicates reserve only the chosen exact source and commit/refund
against its final outcome; see the [payment contract](shared-resource-pools.md#final-result-payment-predicates-s-100).
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
original roll and source bindings. S-225 test rerolls replace only the captured
attack/save test through its owning resolver; they do not replay the spell or
rebuild the cast receipt.

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

### Round and actor action history (S-030)

The shared `when` predicate accepts six Boolean history facts:
`target.first_round`, `target.first_own_turn`,
`target.acted_since_combat_turn`, `target.acted_since_owner_turn`,
`target.attacked_since_combat_turn`, and `target.attacked_since_owner_turn`.
They query the current target's stable combat actor identity. First round is
available after initiative begins and is true only in round 1. First own turn
is unavailable until that actor's first initiative turn starts, then remains
false on later turns. The `*_since_combat_turn` facts use the current
initiative actor's turn-start boundary; `*_since_owner_turn` facts use that
target's most recent own-turn start and are unavailable until that boundary
exists, including under negation. An action means an actual spent Action,
Magic action, or Bonus Action. An attack means a resolved attack occurrence;
misses qualify, canceled targeting and refused actions do not. Attack history
is indexed to the target, not the attacker.

History is encounter-local and bounded to latest event serials per actor. It
resets only on encounter initialization and actual initiative turn starts;
resuming the same active turn after owner reconnection does not create a new
boundary. Menus, queries, map movement and location changes do not change it.
The action-history fixture exercises a real Bonus Action followed by another
actor's owner-turn consumer, and a natural-1 spell attack whose loaded consumer
still settles once. This evidence covers shared-spell predicates through the
interactive combat host; other action/attack hosts, general event subscriptions
and durable campaign history remain out of scope.
Batch E review also checks the existing monster weapon executor's refused
target, miss and hit controls. It records action/attack events only after an
actual roll; rejected AI movement/target selection cannot fabricate an action.
The existing monster spell executor records a committed successful or countered
cast after resolution. Other native commands and broad attack hosts remain
uncertified. Exact evidence and limits are in the
[Batch E review](../../.artifacts/planning/vocabulary-reports/batch-E-review.md).


### Grouped final child outcomes (S-044, accepted VS-42)

Ordered `when` supports `{"child_group":{"mode":"count","steps":["first","second"],"targets":"all","outcome":"failed_save","empty":"fail","skipped":"exclude","comparison":"gte","threshold":2}}`.
`mode` is `all`, `any` or `count` (only count takes comparison/threshold).
Each explicit unique earlier step must be an attack for hit/miss or a save for
successful_save/failed_save. Targets are all actual targets, same current target,
or exact cast_target. Repeated attempts on one target in different steps remain
separate children. Distinct same-definition actors remain separate targets.

Every selected step must carry its completed result before evaluation, including
ANY and already-reached count thresholds. Missing/unfinished results are unknown,
including under negation. Results are written complete only after all children
and their result/damage/concentration choices settle. Final hit/saved flags own
the gate, including supported overrides; natural arithmetic does not replace them.
`skipped` explicitly excludes, counts as nonmatching (`fail`), or makes the group
unavailable. After exclusions, `empty` explicitly passes, fails or is unavailable.
An empty group policy also governs count zero; it is not inferred from arithmetic.
Queries do not roll or pay. This is transient ordered shared-spell result state;
there is no new save permission or durable state, action composition or general
workflow engine.


### Formula inputs and capture policy (S-036, accepted VS-43)

Ordered formula `{"input_value":"amount"}` reads a declared cast input, for example
`"formula_inputs":{"amount":{"kind":"number_choice","minimum":1,"maximum":3,"policy":"captured"}}`.
The real caster popup chooses an integer inside the loaded bounds before the slot
is paid. Wrong type/range, canceled choice, repeated capture and caller decision
substitution refuse. Up to eight inputs, maximum twenty-one integer options in
0..99. Input values live on the exact transient cast host, bound to its owner,
spell and invocation. Direct resolver callers cannot supply them via decisions.

A deterministic actor parameter declares
`{"kind":"parameter","formula":{"caster_ability_modifier":"WIS"},"policy":"captured"}`
or `policy:"live"`. Captured parameters are read once during cast preparation,
after all numeric selections, independent of declaration order; live parameters reevaluate at consumption.
Preparation also checks live parameter availability before costs, without storing
the preflight value. An initially unavailable live-only input refuses before a
slot/action is spent; later consumption still follows the declared live policy. Both survive
later ordered choice continuation with the original host. Live evaluation never
rerolls a committed value. Unknown inputs are unavailable, including before costs.

`{"source_die":{"step":"strike","target":"cast_target","pool_id":"owned_pool","policy":"captured"}}`
reads the committed bonus-die face from an earlier completed attack/save child.
Targets are exact `same` or `cast_target`. The retained receipt records exact
source instance, pool definition, owner, sides and face. Declined/no-die/skipped/
missing or unfinished child cannot supply a value. `captured` uses that committed
receipt even after source removal; `revalidate` additionally requires its exact
owned pool still to exist. Neither policy rolls, pays again, borrows a different
copy or changes the committed face. Existing source selection revalidates before
RNG/payment. Surrounding arithmetic uses the face; formula_reads on effect results
retain the formula and evaluated receipt for inspection.

Supported hosts are ordered combat shared spells and their existing bonus-die
attack/rolled-save choices; numeric choices use the existing popup owner. This
adds no dice inventory, transferable tokens or new durable fields. Inputs, menus,
ordered results and choices remain transient; allowed-save boundaries are unchanged.


S-037 adds declared `progression_lookup` numeric/die-size rows and actual explicit
class-level allocations to those parameter inputs; see [pool/class-level contract](shared-resource-pools.md#explicit-class-levels-and-progression-tables-s-037-accepted-vs-44).
Captured class rows follow the accepted post-number-selection boundary. Total
character level, each class, proficiency and selected slot remain distinct.

## Recipient damage maps and caster-chosen exemptions (S-099 / VS-50)

A Character passive may declare a `recipient_damage_map` for a shared-spell
save. It matches the exact save domain, ability and authored `save_context`
(`cause_id`, `purpose_id`, `origin_effect_id`), and provides independent
`success_scale` and `failure_scale` values from 0 through 1. The target's
matching map changes that recipient's damage only. Ambiguous matching maps do
not choose arbitrarily. The per-recipient save receipt records the selected
map, outcome and scale. Scaling uses the existing floor before typed damage,
resistance and Temporary HP settlement. Evasion's existing rule retains its
normal priority.

A flat shared save spell may author an optional `recipient_exemption_choice`:

```json
{
  "recipient_exemption_choice": {
    "selection_id": "selective_burst_recipients",
    "selection_limit": 1,
    "stage": "before_target_saves",
    "save_ability": "DEX",
    "cause_id": "measured_burst",
    "purpose_id": "contain_area",
    "origin_effect_id": "burst_damage"
  }
}
```

The declaration must match the spell's exact save and save context. The caster
chooses from actual, alive recipients in the selected area through the existing
multi-target control. The cast captures selection ID, spell definition, caster,
eligible recipient IDs and chosen recipient IDs before saves. A transient
selection on the exact cast owns the original caster, invocation, declaration
and recipient objects; caller decision dictionaries cannot grant an exemption.
At settlement the runtime checks those bindings again. A copied actor ID,
replacement recipient or selection from another invocation cannot inherit it.
Chosen recipients take zero spell damage, but their saving throw and
independently authored riders resolve normally. Unchosen recipients use their
own Evasion/map/outcome scale. The exemption is free and shares the ordinary
one-time spell action/slot payment. An empty/deleted target list, source/spell
mismatch, over-limit, duplicate or ineligible recipient grants no exemption.

The current exemption declaration is supported on flat shared spells, not on
ordered spell-step payloads. Damage maps are Character-owned passives. This
subset does not add a general monster-specific map catalog or map arbitrary
damage/effect steps. See the [Batch H build/validation report](../../.artifacts/planning/vocabulary-reports/batch-H-build-validation.md)
for the exact production target scenarios and limits.
The accepted [independent Batch H review](../../.artifacts/planning/vocabulary-reports/batch-H-review.md)
records canonical cast/recipient binding, native Evasion priority and final
production evidence after repairs.

## Incoming damage reductions and bypasses (S-109/S-110; VS-52/53)

Flat shared damage and ordered shared spell damage steps can declare separate
`damage_reductions` and `damage_bypasses` arrays. Ordered declarations belong on
the exact step that owns the occurrence. A single payload retains its explicit
`component_id`, or defaults to `type:1` for flat spells and `step_id:type` for
ordered steps; save component lists retain their own authored/generated IDs.
Reduction has the `after_scale_before_mitigation` stage and a fixed nonnegative
integer or deterministic actor-only formula object. String expressions are
rejected. Initially unavailable formulas refuse before slot/action payment or
dice; settlement reevaluates live actor values after a pending choice. Formula results
are floored, then clamped at zero. A `component` reduction names an exact
`component_id`; an `occurrence` reduction allocates through typed components in
their authored order. Declarations themselves run in authored order. Each
component receives at most its remaining raw damage. Any requested excess is
discarded; it does not carry into another occurrence. No reduction can produce
negative damage.

The component receipt retains original `raw`, `reduction_prevented`,
`reduction_receipts`, `resolved`, `absorbed`, and `hp_loss`. The step outcome
also retains declaration-level `damage_reduction_receipts` with requested,
applied, overflow and allocated component IDs. This reduction occurs after the
save/attack outcome scale and before ordinary mitigation. Temporary HP remains
a later, separate absorption measure.

Bypasses are a separate `damage_bypasses` declaration at the `mitigation`
stage. Scope is `component` with an exact component ID or `occurrence` for every
component in that one occurrence. `layers` must explicitly select one or more
of `resistance`, `immunity`, `ward`, and `prevention`; unknown and duplicate
layers are rejected. The normal settlement order is Resilient Sphere
prevention, Resistance, Ward absorption, Immunity, Temporary HP absorption,
then HP loss. A selected bypass skips only its named layer. Unselected layers,
other components and damage from other sources retain their normal behavior.
Bypass receipts remain on each component and the settlement receipt lists the
layers actually skipped. Reduction receipts never imply a bypass.

The `prevention` bypass crosses the earlier spell-level Resilient Sphere gate
only for ordered shared spells whose steps use typed-component save payloads,
with no riders or other effects. Both the casting controls and direct resolver
honor this narrow gate for a protected caster or target. At settlement,
only components whose own policy selects `prevention` cross the barrier;
unselected components remain blocked. Flat shared spells, other prevention
rules and non-damage effects do not use this bypass. These policy declarations
have no resource cost. They reuse the existing save/attack roll, damage request,
CombatAction and WardRules owners and introduce no saved reservation state.

See the [Batch I build/validation report](../../.artifacts/planning/vocabulary-reports/batch-I-build-validation.md)
for original exercised routes and receipts. The accepted
[independent Batch I review](../../.artifacts/planning/vocabulary-reports/batch-I-review.md)
records repairs, final production controls, commands/logs and exact limits.

## Linked incoming damage (Batch 031; VS-107/108 accepted)

A timed shared spell can grant a source-owned link with an effect such as:

```json
{"type":"grant_damage_link","policy":{"operation":"split","share_percent":50,"rounding":"floor","fallback":"keep_original","require_willing":true}}
```

The spell target is the original recipient; its exact caster is the linked
recipient. The grant is tied to the ordinary spell source instance, lifetime
and concentration record. `operation` is `split` or `redirect`; the integer
`share_percent` is 1–99 for a split and 1–100 for a redirect. `rounding` is
`floor` or `ceil`; it applies to the linked share at the post-scale,
post-reduction split stage, before either actor's mitigation. `fallback` is
`keep_original` or `refuse`; `require_willing` checks the linked actor's live
willingness when damage settles. Missing selected sources may specify the same
fallback in transient damage decisions, otherwise they keep the original
recipient. No attack, rider, cast or payment is replayed. Each recipient gets a
normal independent CombatAction settlement and an entry in the parent
occurrence receipt. With multiple live links, the exact source selector can
choose one; absent a selector the lexicographically first exact source is used.

Source-side damage penalties settle once before the split; each recipient then
applies its own defenses. Monster weapon and flat/ordered shared-spell controls
check concentration for each actual recipient using that recipient's resolved
damage. A full redirect does not force a save on the untouched original target.
Ordered concentration choices retain the original step target and the remaining
recipients; damage and payments do not repeat while those choices settle. Loss
of the link owner's concentration ends the exact link before later steps.
Link grants may share their source with ordinary condition grants, and both
payloads retain their ownership checks through saving and recovery.

The bounded production hosts are monster weapon damage (including poison
riders) and player-cast flat/ordered shared spell damage. The separate monster
spell controller has not been extended with linked-recipient aftermath.
Link-only spells are retained through normal effect pruning and
the supported Overworld save checkpoint; loading validates the exact spell
policy and source/recipient relationship. Pending damage decisions remain
transient. The current link grant fixes the recipient at cast time; this does
not add a per-hit recipient picker or expand damage hosts. See the
[Batch 031 build/validation report](../../.artifacts/planning/vocabulary-reports/batch-031-build-validation.md)
for original builder evidence. The [independent acceptance](../../.artifacts/planning/vocabulary-reports/batch-031-032-acceptance-review.md)
accepts S-111/S-112 as VS-107/108 and records final repairs and current limits.

## Incoming replacements and settled countereffects (Batch 032; VS-109/110 accepted)

Rule anchors: [SRD 5.2.1](https://media.dndbeyond.com/compendium-images/srd/5.2/SRD_CC_v5.2.1.pdf),
printed p.302 Iron Golem (Fire immunity alongside Fire Absorption), p.17 damage
adjustment order, immunity and healing cap, and p.18 Temporary HP before HP.
The incoming-before-immunity policy expresses the absorption interaction; the
generic ratios, partial limits and feedback caps below are authored fixture
policies, not certification of a named spell, class or the monster catalog.

Timed shared spells can grant one automatic response policy to their target:

```json
{"type":"grant_damage_response","policy":{"kind":"replace","damage_type":"fire","stage":"incoming","immunity":"before","measure":"stage_amount","operation":"heal","numerator":1,"denominator":1,"rounding":"floor"}}
```

The ordinary cast source owns the policy, caster, recipient, duration and optional
concentration. Removing that exact source removes its response; sibling sources
remain independent. Loaded spell definitions authorize policies, rather than HUD
or incoming-damage metadata. No new class/creature ID handler is involved. Use
one response grant per spell source; multiple policies need separate sources.

`kind: replace` requires one qualifying `damage_type`, `operation: absorb|heal`,
and an explicit stage/measure/immunity combination:

| Stage | Immunity | Available measure | Position |
|---|---|---|---|
| `incoming` | `before` | `stage_amount` or `raw` | After scaling/reductions, link distribution and the once-only source penalty; before recipient defenses. |
| `resolved` | `after` | `resolved` | After Resistance, Vulnerability, Ward and Immunity; before Temporary HP and HP loss. |

`raw` is this recipient component's original input before incoming reductions;
`stage_amount` is its remaining input at this replacement. `resolved` is its
remaining damage at the resolved replacement. Optional positive integral `limit`
caps how much damage is replaced. Without it, all remaining damage is replaced.
For `heal`, the measured amount is multiplied by the authored ratio, rounded,
and optionally capped by `cap`, then ordinary healing applies the missing-HP
limit and existing healing suppression. `absorb` replaces without healing.
The ratio fields `numerator` and `denominator` are required integers 1–20;
`rounding` is required `floor|ceil`. `cap` is an optional integer 0–100000;
`limit` is 1–100000. Unknown fields/stages/types/measures refuse at loading.

Replacement sources run in exact source-ID order against the remaining damage.
A resolved replacement sees zero on an immune recipient; an incoming replacement
can heal before immunity. Healing receipts capture requested and actual healing
separately from damage. For example, seven resisted to three, with a replacement
limit of two and healing cap of one, heals one then loses one HP: net HP is
unchanged, but actual damage `hp_loss` is one.

Countereffects instead declare a settled receipt measure:

```json
{"type":"grant_damage_response","policy":{"kind":"counter_damage","damage_type":"fire","stage":"settled","measure":"hp_loss","numerator":1,"denominator":2,"rounding":"ceil","recipient":"origin","response_type":"psychic","feedback":"once_per_source_per_root","max_depth":4}}
```

`kind` is `counter_damage` or `counter_heal`. `measure` is `raw`, `prevented`,
`absorbed`, `resolved` or `hp_loss`; `recipient` is the damaged actor (`self`) or
the immediate damage producer (`origin`). Counter-damage requires a supported
`response_type`; counter-healing cannot declare one. Ratio/rounding/cap have the
same bounds as replacements. These measures are captured before countereffects
change HP: later healing never rewrites earlier HP loss. Zero measures do not
activate. Counters run after damage-triggered source termination, before the
concentration prompts; later ordered steps wait for those prompts to finish.

At this boundary, `prevented` is max(0, raw minus resolved), and `absorbed` is
replacement plus Ward plus Temporary HP absorption. These overlap deliberately:
they are different views of the same damage, not quantities to add together.
`resolved` includes Temporary HP damage; `hp_loss` excludes it. Existing shared
spell component `absorbed` and prior-result references retain their accepted
Temporary-HP-only meaning. New component `settlement_absorbed` exposes the full
settlement measure used by these counter policies. The full damage receipt keeps
`ward_absorbed`, `temp_hp_absorbed`, `replacement_absorbed`, `replacement_receipts`
and nested `countereffect_receipts` separate.

Every counter requires `feedback: once_per_source_per_root` and an integral
`max_depth` 1–8. The exact (reacting recipient, source instance) may respond once
within a root occurrence, across its typed components and derived consequences.
The source may fire only when the resulting depth is within its own cap. Marking
it before executing its child prevents reciprocal reentry. A limited response
records its reason and performs no effect/payment. Another source and a later
unrelated root retain their own eligibility. Healing does not create damage or
another trigger. A counter is new derived damage, never another attack, hit rider
or spell cast: it has no original critical multiplier, attack roll, slot, Action,
or source penalty to replay. It still uses ordinary recipient mitigation and HP
settlement. Exact source/root/original-cause/parent-consequence IDs accompany the
receipt; each derived damage occurrence retains its own aftermath entry.
Every executed typed weapon packet remains in recipient aftermath even when
Temporary HP consumes all its damage. The captured `knocked_out` fact still ends concentration if a settled healing
counter subsequently restores HP; later healing cannot erase that consequence.

The exercised hosts are incoming monster weapons (including ordinary poison
riders), and player flat/ordered shared spells, with Character response bearers
and a spell-granted monster absorption bearer. Counter-damage can target the
actual live attacking monster rather than its temporary Character adapter.
Concentration/knockout/defeat handling uses actual recipients; pending choices
retain settled damage and exact source identity without replaying payments.
These automatic policies add no optional paid response picker. Pending
concentration refusal/source loss and stale resolver callbacks use the existing
choice owner. Other weapon/spell controllers, reaction costs, spell reflection,
catalog conversion and arbitrary formula policies are outside this proof.

Policies and ordinary source deadlines persist at the existing allowed Overworld
checkpoint. Both full-save DTO paths validate policy equality to loaded data,
source/owner/recipient identity and ordinary lifetime rules before party restore.
Root IDs, visited sources, depth, callbacks and consequence receipts are transient
and do not enter saves. Recovery restores source state without healing, damage,
acquisition, RNG or a refund. A new incoming occurrence starts a new causal chain.
See the [build/validation report](../../.artifacts/planning/vocabulary-reports/batch-032-build-validation.md)
for original builder evidence. [Independent acceptance](../../.artifacts/planning/vocabulary-reports/batch-031-032-acceptance-review.md)
accepts S-113/S-114 as VS-109/110 after the flat knockout and typed-packet
aftermath repairs; its final controls use a guaranteed-success save to ensure
healing cannot conceal the zero-HP consequence.

## Authored zero-HP eligibility and owned attempts (Batch 033; VS-111/112 accepted)

`Character.take_damage` and `CombatAction.resolve_damage` still call the same
`SharedStepExecutor` event adapter before defeat bookkeeping. Class features and
creature special abilities can declare `type: "zero_hp_replacement"`,
`trigger: "zero_hp"` and ordered `save` / `replace_hp` steps. New class rules are
validated and retained by DataLoader; no definition-ID dispatch is required.

Additional rule fields:

- `bypass_damage_types`, `bypass_critical` retain the typed fortitude exclusions.
  `bypass_outright_death: true` excludes represented massive damage using the
  actual HP damage after Temporary HP, compared with prior HP plus maximum HP.
  Other instant-death/destruction systems are not added here.
- `required_condition` requires that exact condition on the bearer. Missing or
  unknown state cannot qualify. `source_instance_id` names the exact occurrence
  on that actor; siblings must use distinct identities.
- `optional: true` requires a source selection. The owned spell damage request
  suspends before settlement; incoming monster weapons collect authorization
  before their attack roll. Authorization is not an attempt: the zero-HP boundary
  rechecks live source identity, unchanged policy, condition, exclusions and pool.
  These bounded controls may offer authorization even when later mitigation or
  Temporary HP prevents zero HP. Such an answer performs no save, history or cost.
- `history: {"increment":"attempted", "reset_on":["short_rest_completed",
  "long_rest_completed"]}` stores exact-source attempt count. Increment can be
  `attempted`, `accepted`, `success` or `failure`; accepted and attempted coincide
  when an eligible accepted option reaches this synchronous save boundary.
  Queries, decline, invalid/stale sources and excluded damage do not increment.
  Completed `RestRules` events alone perform declared resets; source removal and
  reacquisition preserve the history. Detached source histories also receive
  their declared rest reset. Reset stamps and counts persist.
- `payment: {"source_instance_id":"exact-pool", "amount":1,
  "on":"attempted"}` spends an existing Character numeric pool. `on` may be
  `attempted`, `success` or `failure`; failed saves can therefore pay as authored.
  Every eligible attempt preflights available funds, including conditional costs.
  Attempted payment commits before save RNG; result payment reserves the exact
  quantity and commits/releases it at the declared result.
  This does not acquire or refill pools. Dictionary creatures support unpaid
  automatic replacements; paid creature consumers use the Character owner.

A save step can use `dc_formula`; `replace_hp.replacement_hp` accepts a number
or shared arithmetic tree. The bounded leaves are `caster_level`,
`caster_class_level`, `caster_proficiency_bonus`, `caster_ability_modifier`,
`incoming_damage` and `zero_hp_attempts`. Actor leaves read the bearer; event
leaves read captured resolved damage and the count before this attempt. Strings,
dice, selected slots and earlier spell results are unavailable. All event
formulas preflight before any save RNG or payment; unavailable facts refuse.
HP commits clamp to maximum HP and do not grant Temporary HP.

Example save DC: `{"op":"add","left":10,"right":{"op":"multiply",
"left":5,"right":{"zero_hp_attempts":true}}}`. Example replacement HP:
`{"op":"multiply","left":2,"right":{"caster_class_level":"barbarian"}}`.
Loaded neutral/changed definitions live under `data/fixtures/batch_033/`.

Incoming monster weapon base damage and its original primary poison riders
share the same authorization object. A base packet that never reaches zero
leaves it available for rider damage; a base replacement consumes it for every
later rider. Live source/policy eligibility is rechecked at each zero-HP boundary.

Exactly one eligible replacement executes; an explicit optional source selection
separates siblings. Ambiguous automatic replacements refuse. Native Death Ward
retains its prior precedence; native Relentless Rage remains the existing fallback.
This adds no post-roll bonus/token picker for the new saving throw.
Optional authorization is on the primary incoming target; linked/countereffect
recipients do not gain a separate optional picker in this batch.

`zero_hp_receipt` travels with typed damage components and records source/owner,
old/new attempts, save ability/total/DC/result, HP replacement and payment. Durable
`Character.zero_hp_history` stores that receipt, immutable policy, source/owner,
attempts and reset stamps. The latest receipt's `reset_count` captures the
source's completed-rest count when that attempt occurred. Loading checks its
before/after increment against the declared event and result. In that same reset
generation, current attempts must equal the receipt's after count; a later reset
requires current attempts zero. Attempted/accepted history before its first reset
also agrees with lifetime attempts. Both full-save DTO routes refuse inconsistent
or incomplete history before session replacement. Legacy saves without zero-HP
history retain their existing empty default. Pending choices/live references remain transient and existing save
boundaries remain. Dictionary creature histories are encounter-local; durable
creature history uses the Character path. General revival, forms and destruction
remain later slices. [Acceptance](https://github.com/brandonbrown215bb-boop/DND-Sandbox-Engine/blob/d823423d979f7c566d7511801bd560f5dafb95ee/docs/reviews/batch-033-acceptance.md) records
S-117/S-118 as VS-111/112 after independent repair re-review; broad V-020/V-088
remain partial. Detailed local proof is in
[the Batch 033 report](../../.artifacts/planning/vocabulary-reports/batch-033-build-validation.md)
and [post-review repair evidence](../../.artifacts/planning/vocabulary-reports/batch-033-repair-validation.md).

## Conversion Batch 002 spell boundary

`data/core/spells/conversion_batch_002.json` promotes Hold Monster and Circle of
Death through the existing shared cast pipeline. Their names and IDs only live
in data: renamed copies passed the production loader and generic resolution.
Hold Monster reuses failed-save condition grants, Concentration, selected
upcast recipients and end-of-turn repeat saves. Each Paralyzed condition keeps
the exact spell source; repeat-save success and concentration cleanup remove
only that source. The saved source, cast serial and concentration target survive
both full-party and player-only campaign DTO recovery. It adds no save migration.

Circle of Death reuses Sphere selection, CON save damage with half damage on a
success, upcast dice and carried reusable component checks. Its 500 GP
black-pearl powder remains owned after casting. The live control check covers
cancellation, a stale center after cancellation, an invalid center, mixed saves
and one slot/action payment. Its 60-foot radius is mapped to the current hex
grid; object damage and terrain occlusion remain unsupported.

Cure Wounds and Healing Word remain shared records. Batch 002 removes their
imported Construct/Undead exclusions; ordinary live healing and downed-target
behavior passed. Constructs and Undead are eligible, while dead targets remain
ineligible. Healing suppression and class-specific healing benefits were not
re-audited in this batch. All four records remain gameplay-partial; see the
[Conversion Batch 002 boundary](../planning/vocabulary-slices.md#conversion-batch-002)
and the [four reviewed spell-status rows](spell_status.json).

### Containment eligibility

`containment_targeting` declares individual internal/external target routes.
Both effect and container must permit the route before resources or a source
are spent; outside area recipients exclude internal bodies. See
[containment](containment.md#authored-internal-harm-targeting-and-checks-s-171)
for syntax and the current flat-target/deferred-release boundary.
