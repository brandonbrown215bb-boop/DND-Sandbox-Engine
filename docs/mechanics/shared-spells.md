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
