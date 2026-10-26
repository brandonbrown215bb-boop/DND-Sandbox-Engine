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

### Other attack routes (batch 087)

`CombatState._route_damage_choice(actor, weapon, label, carry, still_error)` is
the one shared host for attacks made outside the Attack action's own swings.
It is data-driven: it reads only `AttackProfileRules.damage_type_choice` and
has no per-ID branches.

| Route | Budget kept | When asked | Carry from Attack action |
|---|---|---|---|
| Opportunity Attack | Reaction | after the player accepts the reaction prompt, before `reaction_available` is cleared | never |
| Light extra attack (Bonus Action) | Bonus Action + once-per-turn Light use | after the optional-attack prompt, before either is spent | never |
| Light extra attack with Nick | once-per-turn Light use (no Bonus Action, SRD Nick: part of the Attack action) | same | yes, an `attack_action` pick |
| Cleave | once-per-turn Cleave use | after the optional-attack prompt, before the use is spent | never (SRD: a separate extra attack) |
| Created creature's turn attack | the creature's own action | before the attack is resolved or the action spent | never |

- **Carry rule:** a pick made during the Attack action is reused only by attacks
  that are *part of that Attack action* and only when the rule says
  `choice_duration: attack_action`. Of these routes that is only Nick. Every
  other route is its own attack and asks its own menu, whatever the duration.
- **Activation window:** the menu is asked before the route's budget is spent.
  Afterwards the host rechecks the rule (`activation_choice_error`) and the
  route's own validity: budget still unused, actor still able, target alive and
  still within reach (for OA, the mover's left hex; for created creatures, the
  creature has not moved). A dismissal or stale answer makes no attack, spends
  nothing, and logs `<route> is not made and nothing was spent`. It never falls
  back to the weapon's type.
  Created-creature turns also recheck the active creature, turn, Action and
  live controlled attack order. A successful attack spends the creature's
  Action before hit settlement, including any hit-window menu. Light, Cleave
  and Opportunity choices retain live reach/barrier and turn checks.
- **Hit window:** the budget is spent when the attack is made, as before. The
  menu follows the hit through `_settle_attack_profile_hit_choice`; a dismissal
  uses the weapon's own type and logs it (the existing hit-window rule).
- No durable state is added; the choice lives in memory for one attack.
  Legacy saves are unaffected.

### PARTIAL
- Batch 077 closes the old first-swing-only gap: every Extra Attack swing hosts
  its own activation or hit choice per `choice_duration`.
- Batch 087 closes the route gap for Opportunity Attacks, Light (off-hand,
  including Nick), Cleave and created-creature turn attacks (see "Other attack
  routes" below). Still not hosted: S-156 commanded created actors
  (`CreatedCommandRules`, synchronous), Conjure-style summon attacks and monster
  attacks; they settle with the inherited type.
- Item-granted attack profiles aren't supported, because items grant only
  `mode_choice`/`rule_upgrade` features. Reach and mastery choices aren't built.

## Cast-local transformations (S-140, batch 085)

A spell-scoped `attack_profile` may change one permissioned invocation's
range, components, school or timing. `AttackProfileRules.apply_cast(caster, spell)`
returns a transformed copy. `CombatState` calls it on the player
HUD cast path after the permissioned command is built, before Quickened offers,
the initial action-budget check, targeting or payment. Selection reuses that
captured copy without applying the transformation again.

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
  casting_time, components, duration_seconds, concentration}, removed_components}` lives only on the invocation
  copy. The catalog record is never mutated, and casts that no source qualifies
  for get no profile.
- **Cost:** the transformation costs nothing. The invocation pays its own slot
  and action exactly once, using the transformed timing. Budget validation
  refuses before payment, so a Bonus Action cast with no Bonus Action left keeps
  its slot and Action. A target outside the transformed range is refused before
  payment as well.
  Both timing directions can begin when the original budget has been spent
  and the transformed budget remains available.
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
- The S-141 continuation below supplies duration/concentration for flat shared
  condition grants. Other lifetime owners and created-actor parameters remain open.

## Cast-local condition lifetimes (S-141 continuation)

A spell profile can replace `duration_seconds` (an integer from 1 through
86400) and/or `concentration` (a Boolean) on one permissioned player HUD cast:

```json
{"type": "attack_profile", "source_instance_id": "feature:unbound_weave",
 "scope": {"kind": "spell", "ids": ["example:timed_condition"]},
 "replace": {"duration_seconds": 120, "concentration": false}}
```

This first host accepts **flat shared spells with an existing positive duration
and only `grant_condition` effects**. Instantaneous, native, ordered, persistent-area,
source-benefit, tether, projection and created-actor lifetime owners refuse
these changes before payment. Source-benefit carriers retain their stricter
catalog-bound saved lifetime contract; accepting a profile is not permission
to bypass that contract. Weapon profiles cannot contain either lifetime field.

Lifetime fields use the same inherited scope and first-replacement precedence
as other cast fields. Compatible changes combine once; later conflicting values
are recorded as ignored. The invocation's displayed duration is updated too.
Selections with lifetime changes capture their qualifying rules; before
Metamagic or spell payment the host rechecks that set. A removed, changed or
additional qualifying lifetime source refuses that pending cast, preserving its slot, action and existing
concentration. Cancellation and stale target clicks likewise create no source.

`SpellEffects.begin_cast` captures the invocation's final duration and
concentration flag. Adding concentration uses ordinary replacement/cleanup;
removing that requirement leaves an older concentration source alone. Each
recipient ages/removes only its own exact source. Combat boundaries use the
existing six-second ticks; exploration uses campaign seconds. Later changes
to the modifying feature do not rewrite effects already cast.

The existing source `remaining_seconds` and `concentration` fields survive
full-party and player-only checkpoints; no new save schema or migration is
introduced. The transient `_cast_profile` and pending selection are not saved.
`cast_lifetime_flow` and its automatic fresh-process `cast_lifetime_reload`
exercise the real HUD, cancellation/staleness, payments, concentration
replacement, captured expiry and recovery. `CastLifetimeChecks` covers
composition, validation and the existing Extended Spell duration calculation;
this does not migrate native Metamagic or certify its complete player flow.

S-141 remains partial: source-benefit carriers and other lifetime owners,
created-actor parameters, resource-paid profiles and additional casting hosts
are separate continuations. No catalog spell or feature conversion is claimed.
