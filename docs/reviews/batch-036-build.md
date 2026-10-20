# Batch 036 build: source-end aftermath and last-charge aftermath (S-086, then S-060)

Built 2026-10-20 by Runtime Builder on branch `batch-036-s086-s060`. The
branch stacks on `batch-035-s130-s126` @ `7c559c8`; origin had not moved
when it was fetched again before the push. **Build evidence only.** Slice
counts, VS numbers and the checkpoint are unchanged until independent review
and owner acceptance.

## Scope implemented

Two shared modules follow ADR-0018: JSON declares the behavior, no content ID
is branched on, and the consumer changes are small and neutral. No catalog
records were rewritten, `tools/content_editor/` is untouched, and no 036 code
reads creature type.

### S-086: source-end reason and located aftermath (deps S-014, S-072)

- `src/spells/source_end_aftermath_rules.gd` (`SourceEndAftermathRules`).
  Shared spells can declare `end_aftermath`: 1–8 entries of `{id,
  reasons: [exact end_reason strings], effects: [{type: damage, amount,
  damage_type} | {type: condition, condition, rounds}]}`. The shared-spell
  content check validates it, and the field is on the allowlist.
- `SpellEffects.begin_cast` captures the field on the exact source record.
  The existing `SpellEffects.remove` is still the single final end point, and
  each removal produces exactly one end event. That event now fires only the
  entries whose declared reasons contain its `end_reason`, on the recipient
  that held the source.
  - The receipt is `event.aftermath`, with the aftermath id, source, reason,
    origin id, the creature's `hex_position`, and effect results.
  - Damage settles through `CombatAction.resolve_damage` with the source and
    caster as its cause.
  - The event is recorded after its follow-ups.
- Reasons are not conflated: `expired`, `concentration_ended`, `dismissed`
  and the existing event types are matched exactly. An undeclared reason still
  emits its one final event, with no follow-up. A removed source cannot emit
  again.
- Saves: a saved record's captured `end_aftermath` must equal the definition
  and be valid. Legacy records without the field still load.

### S-060: last-charge aftermath on exact copies (deps S-049, S-042)

- `src/characters/last_charge_rules.gd` (`LastChargeRules`). Item
  definitions can declare `last_charge_aftermath: {outcome: destroy|degrade,
  roll?: {die, trigger_on: [faces]}, keep_properties?: [...]}`. It requires
  `maximum_charges` and is validated at item load.
- `Inventory.spend_instance_charges`, the existing exact-copy spend boundary,
  settles the aftermath once when a real spend takes that copy from more than
  0 charges to 0.
  - The declared roll uses game dice.
  - `destroy` destroys only that copy.
  - `degrade` keeps the copy's identity, sets `state.degraded = true` and
    `state.magical = false`, and records the kept properties. A degraded copy
    no longer recovers charges at dawn.
  - The receipt is `Inventory.last_charge_receipt`, which is transient.
- A copy that is already empty cannot spend or roll again.
- Saves: the inventory-copy validator accepts the degraded marker only for a
  declared `degrade` item at 0 charges. Legacy states still load.
- The batch 034 gear-policy helper now honours a copy's `state.magical`, so a
  degraded copy counts as nonmagical.
- The native Wand of Magic Missiles last-charge path is unchanged. Its catalog
  record has no `last_charge_aftermath`, so it cannot settle twice.

## Fixtures (bounded, production loader)

- `data/fixtures/batch_036/spells/marks.json`: a concentration mark lasting
  12 s. Expiry deals 3 force damage; dismissal or concentration end applies
  prone for 1 round.
- `data/fixtures/batch_036/items/wands.json`: a 3-charge wand destroyed on a
  d20 roll of 1, and a 2-charge rod that degrades and keeps `light`.

## Commands (Linux box, Godot 4.7.2-stable, worktree `/workspace/wt-036`)

```bash
G=/workspace/godot/Godot_v4.7.2-stable_linux.x86_64
$G --headless --path . --import
git checkout -- docs/reviews/*.translation
TEST_SUITE=logic TEST_LOG_DIR=/tmp/tl36 bash run_tests.sh $G
$G --headless --path . res://scenes/viewport_harness.tscn -- --scenario=<name>
```

The new scenario `batch_036_end_and_charge_flow` is registered in
`src/viewport_harness.gd` and `run_tests.ps1`.

## Log summary

| Run | Result |
|---|---|
| Import | exit 0 |
| parse_gate / boot_gate | PASSED |
| Logic suite | **4862 passed, 0 failed** (adds `Batch036Checks`) |
| `batch_036_end_and_charge_flow` | **7/0** |
| `batch_035_profile_max_hp_flow` | 7/0 |
| `batch_034_aftermath_flow` | 10/0 |
| `batch_033_zero_hp_flow` | 70/0 |
| `batch_032_damage_responses_flow` | 33/0 |
| `batch_031_linked_damage_flow` | 25/0 |
| `shared_spell_flow` | 67/0 |
| `downed_area_damage_flow` | 2/1, already failing on `main` d823423 (unchanged) |
| `party_recovery_flow` | 17/2, already failing on `main` d823423 (unchanged) |

## Receipts (from logs)

- Actual cast on the goblin, then concentration end: one
  `concentration_ended` event. Its aftermath is only `recoil` at origin
  `monster_0`, location (1, 0). The goblin is prone and its HP is unchanged.
- Actual cast on a party member, then 12 s of time: one `expired` event, 3
  force damage, and no prone.
- Inventory: degrading a party member's rod affects only the spent copy and
  survives `to_dict`/`from_dict` with the same instance id.
- Logic checks:
  - S-086: expiry, dismissal, concentration end and undeclared-reason
    controls; a repeat removal or a second expiry is a no-op; the creature
    host's location; saved changed aftermath is refused and a legacy record
    loads; malformed aftermath (4 cases) is refused.
  - S-060: a non-final spend has no aftermath; a roll of 1 destroys one exact
    copy and leaves the other; a roll of 7 keeps the empty copy; an empty copy
    cannot re-spend; degrade and no dawn recovery; DTO validity and restore;
    malformed policies (3 cases) and saved-state rules.

## Limits

- **S-086:**
  - The host is shared-spell source records only. Item, feature and created
    actor sources are not covered.
  - Follow-ups apply to the recipient that held the source. Area effects at a
    location and effects on other actors are not represented, and `location`
    is recorded only for creatures.
  - No death or destruction end reason is emitted automatically. A source
    ends with `death` only if the caller removes it with that reason.
  - Follow-ups cover damage and conditions only.
- **S-060:**
  - The only consumer is `spend_instance_charges`, and its only production
    caller is the native wand path, whose catalog record is not converted.
    The scenario therefore spends through the inventory boundary directly.
  - The receipt is not saved.
  - Degradation does not remap the definition to a mundane item id;
    `keep_properties` is recorded, not enforced.
- There is no fresh-process relaunch probe; save round trips are covered in
  logic and the scenario.
- Independent review is pending.

## Source manifest (sha256, first 16 hex)

| File | sha256/16 |
|---|---|
| src/spells/source_end_aftermath_rules.gd | a25ec2f660ec8b8e |
| src/characters/last_charge_rules.gd | dada28f24e9494ae |
| src/batch_036_checks.gd | 8e69e46440b99510 |
| src/batch_036_controls.gd | 41bf4af29b94f631 |
| data/fixtures/batch_036/items/wands.json | 9d18461c38371919 |
| data/fixtures/batch_036/spells/marks.json | cb037e4055d0c92a |
| src/spells/spell_effects.gd | 2718d4f950263c01 |
| src/spells/shared_spell.gd | 75e8656881006b08 |
| src/spells/spell_effect_persistence.gd | a7399fe63a237bff |
| src/characters/inventory.gd | c4be3b9c9f0b2637 |
| src/characters/inventory_copies.gd | 375c958930af2eac |
| src/autoload/data_loader.gd | 31680c5302085c20 |
| src/combat/zero_hp_aftermath_rules.gd | 694cdf35d275f812 |

Also changed: `src/test_runner.gd`, `src/viewport_harness.gd`, `run_tests.ps1`.
