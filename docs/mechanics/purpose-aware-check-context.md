# Purpose-aware skill-check context

The current bounded check-context behavior uses the existing event-table and
`EventDialog` path. A context-aware check must come from a uniquely identified
loaded event/check record. Its authored `check_context` contains `task_id` and
`purpose_id`, plus an optional `required_tool_id`:

```json
"check_context": {
  "task_id": "survey_archive",
  "purpose_id": "locate_nest",
  "required_tool_id": "example:surveyors_tools"
}
```

`task_id` and `purpose_id` are lowercase identifier tokens. Ability and skill
remain the event check's ordinary `ability` and `skill`; the original DC and
roll rules remain on that check. `EventDialog` resolves the event and check
from `DataLoader` before rolling. For a context-aware check, the loaded check,
not copied popup fields, supplies the ability, skill, DC, purpose and
consequences. Unknown or ambiguous context checks are closed without rolling
or applying their caller-provided consequences.

`required_tool_id` may be omitted when no tool is required. A valid tool may
also be named without any bonus effect; the check still uses its ordinary
ability, skill, DC and consequences. Task/purpose context describes the check,
while only a matching item effect grants the checked bonus.

A tool item may declare one or more `skill_check_context_bonus` effects. Each
effect names its own `id`, ability, skill, task, purpose, required tool, source
event, source check and a fixed bonus from 1 through 20. The item must be a
tool, and its `required_tool_id` must equal that item's ID. DataLoader checks
that each bonus effect points back to a loaded event/check with matching
ability, skill, task, purpose and required tool. Context checks do not need a
bonus effect. The runtime still checks the exact context at roll time.

The benefit applies only while the rolling character owns that exact item
copy in the backpack or an equipment slot. The result records actor, item,
copy instance, location, effect and originating event/check. Removing or
transferring that copy ends only its eligibility; another actor's copy does
not transfer the first actor's source identity. The bonus adds to the normal
skill-check modifier and does not change natural d20, DC, roll mode or action
cost. It adds no post-roll choice or extra cost.

Loaded checks with unique IDs retain verified origin even without task/purpose
context. The general owned modifier filters are described in
[owned modifiers](owned-ability-check-modifiers.md#optional-event-filters).
Ordinary checks without declared context keep their native behavior, including
existing free-text tool behavior. Direct/local-room checks do not acquire
event-table context from caller metadata. Other purpose-sensitive checks,
sensory requirements, post-roll choices and rerolls remain outside this
boundary. The broader check and reroll work remains separately scheduled.

## Shared-spell save cause and sensory eligibility (S-029)

The supported save host is a shared spell's flat save or ordered `save` step.
Loaded shared-spell data may declare a structured cause and purpose:

```json
"save_context": {
  "cause_id": "poison_exposure",
  "purpose_id": "avoid",
  "origin_effect_id": "spore_burst"
}
```

For ordered saves, `save_context` may be declared on the save step; otherwise
the spell-level value applies. `cause_id`, `purpose_id`, and
`origin_effect_id` are lowercase identifier tokens. The runtime receipt adds
the exact `spell_definition_id`, `source_definition_id`, `source_instance_id`,
`source_owner_id`, cast `invocation_id`, and ordered `step_id` when present.
These values come from the loaded save and owned cast context, never popup or
log prose. A save without `save_context` remains an ordinary save.

An owned passive `failed_save_numeric_bonus` can optionally add `cause_id`,
`purpose_id`, and `required_sense`. If either cause or purpose is present, both
must match the originating save context. The existing ability filter still
applies. Supported `required_sense` values are `see` and `darkvision`, checked
by `CombatPerception` against the saving Character's live encounter position,
the captured cast origin, and the live grid. `darkvision` requires both its
represented range and usable sight; blindness and blocking walls cannot qualify.
Missing spatial context and unmodeled senses such as
hearing are unavailable. No sense field means the existing ability-only
eligibility behavior.

Sense is queried when the existing failed-save choice is offered and again
when the selected source is committed. A changed or unknown sense or an
unavailable source refuses that selection before payment. In the production
spell continuation, a refused selected source then follows the existing
decline path: the chooser closes, the original save consequences resume, and
the source is not charged. The lower-level settlement call itself leaves its
request unconsumed on refusal, but the production continuation consumes it by
settling as a decline. Cause/purpose and canonical source IDs remain captured
in the choice receipt through settlement. This covers loaded shared-spell
saves only; S-028's EventDialog checks retain their existing task, purpose, and
tool contract. It does not add Death Save or concentration roll choices,
hearing, local-room checks, general interpretation, or S-190's
observer-specific perception system. Durable saves are not involved; the
pending choice remains transient.
