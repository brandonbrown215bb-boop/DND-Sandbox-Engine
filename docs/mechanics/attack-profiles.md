# Attack profiles and weapon damage-type choices

`AttackProfileRules` (`src/combat/attack_profile_rules.gd`) reads `attack_profile`
features from the actor. S-126 (Batch 035) added scoped replacement of ability,
damage die and damage type. The first qualifying source's `replace` wins.
Profiles are applied to a per-attack copy of the weapon and never to the catalog record.

## Damage-type choices (S-127, Batch 067)

A weapon-scoped rule may offer types instead of fixing one:

```json
{"type": "attack_profile", "source_instance_id": "...", "scope": {"kind": "weapon", "ids": ["longsword"]},
 "choice_window": "activation", "replace": {"damage_type_choices": ["radiant", "force"]}}
```

- `choice_window` is required and must be `activation` or `hit`. The engine has no default.
  The loader refuses a rule with choices and no window, a window and no choices,
  or both `damage_type` and `damage_type_choices`.
- If a fixed `damage_type` source wins first, no choice is offered.
- **Activation window:** live combat Attack asks for the type after the target
  is clicked and before the action, swing or any other cost is committed.
  Dismissing the menu spends nothing. After the answer, the engine rechecks the
  source, the option, the target's position and life, and that an action remains.
  A stale answer is refused, and nothing is spent.
- **Hit window:** `CombatAction._settle_weapon_attack_context` pauses after the
  final hit and every pre-damage payment, but before damage is rolled. It returns
  `attack_profile_choice_request`, and only when the caller sets
  `allow_attack_profile_choice`. `AttackProfileRules.resume_hit_choice` settles
  the request once, and a replay is refused. Dismissing the choice, or making it
  after the source has left, keeps the weapon's own type. The choice costs nothing.
- **Duration (batch 077, #39 follow-up):** optional `choice_duration` is
  `attack` or `attack_action`; any other value, or a duration without choices,
  is refused. Brandon's ruling: "ask on every swing for a choice that applies to
  one attack. Carry it across the Attack action only when the feature says it
  lasts that long." A rule that omits the key is read as `attack` (never a
  carry), so existing data keeps working.
  - `attack`: every swing asks again, including each Extra Attack swing of one
    click (activation menu before that swing; hit menu after that swing hits).
    Each pick changes its own swing only.
  - `attack_action`: the first pick is kept in `CombatState.attack_action_damage_choice`
    (memory only, cleared when a new Attack action is spent or a turn starts)
    and reused by later swings of the same Attack action, including a later
    click. It is rechecked each swing: same source, still an option.
  - Refusal is never silent: dismissing (or a stale answer to) a later swing's
    activation menu holds that swing, logs it, and leaves it available for the
    next click; a dismissed hit-window menu logs that the weapon's own type is used.
  - After an activation menu yields, the host rechecks the attacking turn,
    incapacitation, live target, range, sight and melee barrier before spending
    the swing. A second-swing target moving out of reach leaves that swing held.
- The chosen type applies to that attack only (unless carried as above). Nothing new is saved; the pending
  request lives in memory only, and class-owned rules are rebuilt on load.

### PARTIAL
- Batch 077 closes the old first-swing-only gap: every Extra Attack swing hosts
  its own activation or hit choice per `choice_duration`.
- Opportunity, Light (off-hand), Cleave and created-creature attacks don't host
  the choice. They settle with the inherited type.
- Item-granted attack profiles aren't supported, because items grant only
  `mode_choice`/`rule_upgrade` features. Reach and mastery choices aren't built.

## Cast-local transformations (S-140, batch 085)

A spell-scoped `attack_profile` may change one permissioned invocation's
range, components, school or timing. `AttackProfileRules.apply_cast(caster, spell)`
returns a transformed copy. `SpellCastSelection.choose` calls it on the player
HUD cast path after the menu row is chosen and before targeting or payment.

- **Fields:** `replace.range_feet` (positive multiple of 5, max 5280; sets the
  hex range and drops any level-based range table), `add.range_feet` (sums;
  also lifts each level-table entry), `replace.school` (one of the valid schools),
  `replace.casting_time` (`action` or `bonus_action`), and
  `remove.components` (`V` and/or `S`). Anything else on a spell profile,
  spell fields on a weapon profile, `remove` on a weapon profile, and
  `scope.permission_sources` on a weapon profile are refused at load.
- **Scope:** `ids`, `schools` and `permission_sources` (the `source_id` of the
  permission the cast is made through). Scope is judged on the invocation's
  **inherited** fields, so one source's school change never makes another source
  qualify, and it doesn't change which save-DC profiles apply.
- **Compatibility:** the first qualifying `replace` of each field wins. Later
  conflicting replacements go into `_cast_profile.ignored` as `{source, field}`.
  Range additions sum and removed components union. All qualifying sources
  apply together, once: a copy that already has `_cast_profile` comes back
  unchanged.
- **Record:** `_cast_profile = {sources, ignored, inherited{range, school,
  casting_time, components}, removed_components}` lives only on the invocation
  copy. The catalog record is never mutated, and casts that no source qualifies
  for get no profile.
- **Cost:** the transformation costs nothing. The invocation pays its own slot
  and action exactly once, using the transformed timing. Budget validation
  refuses before payment, so a Bonus Action cast with no Bonus Action left keeps
  its slot and Action. A target outside the transformed range is refused before
  payment as well.
- **Not applicable:** range is never changed for Touch or range-0/self spells.
  Timing is never changed for reaction or longer casting times. Removing a
  component the spell doesn't have does nothing.
- **Durable state:** none. Rules are features owned by their source, the profile
  is memory-only, and nothing new is saved.
- **Related fix:** a Wand of Magic Missiles activation used to write its
  activation markers into the catalog Magic Missile record. Every later Magic
  Missile cast was then treated as a wand activation. It now uses a copy.

### PARTIAL (batch 085 bound)
- Only player HUD casts through `SpellCastSelection.choose` are transformed.
  Reaction casts, AI or monster casts, exploration or local-room casts, and
  magic-item activations get the catalog values.
- Material components can't be removed, so costly and consumed materials and
  focus rules don't change.
- Timing changes only between Action and Bonus Action.
- There are no costed transformations (resource-paid profiles). Native
  Metamagic (Quickened, Subtle, Distant) still uses its own host and isn't
  migrated yet.
- Duration, concentration and created-actor parameters are S-141, which follows
  after this batch.
