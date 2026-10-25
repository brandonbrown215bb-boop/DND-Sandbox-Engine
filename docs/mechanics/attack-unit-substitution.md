# Attack substitutions and child actions

Batch 028 provides opt-in shared behavior for an active Character in combat.
No spell, class or item catalog conversion is implied. Loaded neutral examples
are under `data/fixtures/batch_028/`.

## Remaining Attack and Flurry units

An Action spell, consumable item, or ordinary self-healing class activation can
opt in with `"attack_unit_substitution": {"units": 1}` or `{"units": 2}`.
Only loaded definitions and currently owned sources authorize this permission;
command metadata cannot create it. Healing activations use `class_feature`,
ordinary feature uses, and only `heal`/`heal_self` effects; numeric-pool or targeted
healing activations are outside this host. Consumables use the exact selected
backpack copy and their existing supported effects.

The first actual Attack or Flurry strike pays the parent Action or Bonus/Focus.
For actors with substitution consumers, remaining strikes stay available for
separate targeting instead of being immediately spent on the first enemy.
Other actors retain their existing automatic Extra Attack behavior. Attack and
Flurry retain separate quantities; selecting Attack changes the current parent
back to Attack. Continue Flurry through its existing feature control.

The spell/item/heal replaces its declared one or two remaining units and pays
its own slot, item copy or feature use. It does not pay a second parent action.
Spell target cancellation preserves units/payment. Selected source, remaining
units and the active actor/turn revalidate before spell payment. Committed spells,
including interrupted spells, consume their units once. Ordinary Counterspell
refunds the exact prepaid spell slot while retaining the used parent units.

## Declared child actions

An active `class_feature` activation can declare an Action, Bonus Action or
Reaction parent with ordinary feature uses:

```json
{
  "id": "example:sequence",
  "name": "Sequence",
  "executor": "class_feature",
  "type": "active",
  "target": "self",
  "action_cost": "bonus_action",
  "uses": 2,
  "uses_per": "long_rest",
  "effects": [],
  "child_actions": {
    "classification": "example_sequence",
    "cancel_policy": "skip",
    "children": [
      {"id": "strike", "kind": "strike"},
      {"id": "cast", "kind": "cast", "spell_id": "example:owned_spell"},
      {"id": "step", "kind": "move", "distance": 2}
    ]
  }
}
```

Declare 1–12 distinct child IDs. Supported kinds are a single ordinary equipped
weapon strike, a currently permitted shared Action spell, and ordinary movement
up to the declared distance in hexes. Spell resource/component costs and movement
distance still pay normally. A child's action cost is waived locally; unrelated
Action, Bonus, Reaction and Attack quantities are preserved. A strike child does
not create Extra Attack units. Reaction parents can be selected on the active
actor's turn; off-turn trigger scheduling is separate work.

Unsupported declarations or unavailable spell references refuse before parent
payment. Starting an available parent pays its action/reaction and feature use
once, then opens the child chooser. Select remaining children in any order;
settled children disappear and cannot replay. Canceling targeting follows the
explicit policy: `skip` removes that child and offers its siblings; `stop` ends
the parent. Closing the chooser ends it. Neither policy refunds the already paid
parent or restarts it. Invalid targets remain available for correction/cancel.
Source loss or turn/actor changes invalidate continuation. Delayed old popup
answers cannot clear, unlock or reclassify a newer parent's selection.

Children retain the parent invocation, feature source and declared classification.
Weapon rider receipts receive that classification, including after post-roll
choices. Spell cast/resolution contexts retain the parent source/invocation,
while their own spell/source and invocation identities remain distinct.
Counterspell resumes the same parent's remaining children once.

Parent state is encounter-local and never saved. Existing allowed-checkpoint,
legacy-save and source-ownership boundaries remain. Recursive parents, targeted
non-spell healing, monster parents and off-turn trigger authoring are unverified.

The child selection/completion/cancellation helpers also serve the bounded
[located source-end continuation](source-end-rules.md#located-end-continuations).
Its room-owned ordered heal/object/entry-hazard children have their own durable
receipts and room controls; this does not make combat parents saveable or add
those child kinds to `child_actions` declarations above.

[Current production evidence](../../.artifacts/planning/vocabulary-reports/batch-028-build-validation.md)
and [independent review](../../.artifacts/planning/vocabulary-reports/batch-028-completion-review.md)
own validation and acceptance.
