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
Attack types are `ranged_spell` and `melee_spell`. **Current implementation
limit:** a shared record cannot yet combine `attack_type` and `save`. The loader
rejects that combination. This is a gap in the first contract, not the intended
spell architecture; mixed and sequential checks belong in shared execution
under [ADR-0017](../decisions/0017-shared-json-spell-execution.md).
`scaling` maps character-level strings to damage
formulas. `upcast` supports damage dice, healing dice or fixed healing/Temporary
HP increases and `additional_targets_per_level`.
Upcast dice are plain expressions such as `1d6`. Fixed healing increases require
an integer base healing value; choose either fixed or dice healing increases.
Healing and Temporary HP increases apply every additional slot level.

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
These flags inspect the current delivery result; adding `on_failed_save` to
an attack effect does not cause a follow-up saving throw.

## Mixed checks: required direction, not yet executable

The shared path is intended to represent an attack followed by a save on hit,
an attack followed by an area save regardless of hit/miss, and a save enabling
a later attack. Those steps need explicit order, targets and conditions, with
each check controlling only its declared payloads. For example, attack damage
can resolve before a save against a secondary condition; a successful save
then prevents that condition without undoing the attack damage.

The ordered-step JSON format and its runtime are not implemented yet. Do not
put both top-level fields into a shared record or assume effect gates supply
the missing check. Existing mixed spells keep their dedicated paths until
the reusable sequence is implemented and verified. A later `repeat_save` on
a timed condition is already supported, but is a separate lifetime mechanism.

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
