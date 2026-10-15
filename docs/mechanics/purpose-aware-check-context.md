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

Ordinary checks without declared context keep their existing path, including
existing free-text tool behavior. Direct/local-room checks do not acquire
event-table context from caller metadata. Other purpose-sensitive checks,
sensory requirements, post-roll choices and rerolls remain outside this
boundary. The broader check and reroll work remains separately scheduled.
