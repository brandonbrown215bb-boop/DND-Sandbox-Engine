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
- The chosen type applies to that attack only. Nothing new is saved; the pending
  request lives in memory only, and class-owned rules are rebuilt on load.

### PARTIAL
- Extra Attack swings in the same click use the hit window if the rule has one.
  An activation-window choice is asked only for the first swing; later swings
  inherit the weapon type.
- Opportunity, Light (off-hand), Cleave and created-creature attacks don't host
  the choice. They settle with the inherited type.
- Item-granted attack profiles aren't supported, because items grant only
  `mode_choice`/`rule_upgrade` features. Reach and mastery choices aren't built.
