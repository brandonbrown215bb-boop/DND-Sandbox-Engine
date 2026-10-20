# Batch 035 build: source-owned maximum HP and scoped attack/cast profiles (S-130, then S-126)

Built 2026-10-20 by Runtime Builder on branch `batch-035-s130-s126`. The
branch stacks on `batch-034-s093-s119` at `e3efcad` (after the reviewer's
cc04662 fix). **This is build evidence only**: slice counts, VS numbers and the
checkpoint are unchanged until independent review and owner acceptance.

## Scope implemented

There are two shared modules, following ADR-0018: JSON declares behavior, no
content ID is branched on, and the existing consumers get small, neutral
changes. The catalog is not rewritten, and `tools/content_editor/` is
untouched.

### S-130: source-owned maximum-HP changes (deps S-048, S-109)

- `src/characters/max_hp_source_rules.gd` (`MaxHpSourceRules`). A rule has
  `{id, kind: increase|reduction, amount: int|"damage_dealt", accumulate?,
  floor? (>=1), cure_on?: [short_rest_completed|long_rest_completed|turn_started],
  periodic?: {event, amount} (reductions only), raise_current?}`.
- `Character.max_hp_sources` stores one entry per exact source instance. Each
  entry records the amount requested and the delta actually applied after the
  floor clamp. `max_hp` stays the single additive value that the rest of the
  engine already reads, and current HP is clamped to it.
- Removal reverts only that source's applied delta, so equivalent sources
  (the same rule from different instances) never revoke one another.
  Re-applying a non-accumulating source does not stack. An accumulating source
  adds to its own request.
- Periodic growth applies on the declared event. Cures apply on completed
  `RestRules` Short/Long Rests (before HP restoration) and on
  `CombatAction.advance_combat_turn` (`turn_started`).
- An existing maximum protection (Aura of Life sources) refuses reductions.
- Saves: `to_dict`/`from_dict` carry `max_hp_sources` and restore without
  replaying deltas. `MaxHpSourceRules.saved_error` is wired into both
  `SaveManager` full-save DTO routes. Legacy saves without the field still load.
- Neutral consumer: a monster attack `extra_effects` entry of type
  `max_hp_source` with an embedded rule. The source id is
  `<creature id>:<rule id>`. `DataLoader` validates the rule at load.
- The native `reduce_max_hp` rider is unchanged.

### S-126: scoped actual attack/cast profile (deps S-036, S-024)

- `src/combat/attack_profile_rules.gd` (`AttackProfileRules`). The Character
  feature type is `attack_profile`, with `{source_instance_id, scope:
  {kind: weapon|spell, ids?, properties_all?, melee?, schools?},
  required_condition?, replace: {ability, damage_die, damage_type |
  damage_type_choices, attack_bonus, save_dc}, add: {attack_bonus,
  damage_bonus, save_dc}}`. `DataLoader` validates it on class features.
- Weapons: `resolve_weapon_attack` transforms its existing per-attack copy
  before the ability bonus is appended to the damage formula. For each
  replaced field, the first qualifying source wins. Additive bonuses sum, and
  fields no source touches are inherited. A chosen damage type must be one the
  profile offers (`decisions.attack_profile_damage_type`); otherwise the
  inherited type is kept. The receipt is `_attack_profile`.
- Spells: `SpellPermissionRules.save_dc` applies scoped save-DC replacement
  and/or addition. An explicit `_save_dc_override` still has the final say.
- Catalog records (weapons and spells) are never mutated.
- 035 code reads no creature type.

## Fixtures (bounded, production loader)

- `data/fixtures/batch_035/classes/profile.json` has three profile features:
  a condition-gated melee ability/die/type-choice profile, a longsword
  fire-type +1 attack/+2 damage profile, and an evocation DC +2 profile.
- `data/fixtures/batch_035/monsters/drainer.json` is an attack carrying an
  accumulating damage-dealt reduction, cured by a Long Rest and growing by 1
  at each turn start.

## Commands (Linux box, Godot 4.7.2-stable, worktree `/workspace/wt-035`)

```bash
G=/workspace/godot/Godot_v4.7.2-stable_linux.x86_64
$G --headless --path . --import
git checkout -- docs/reviews/*.translation
TEST_SUITE=logic TEST_LOG_DIR=/tmp/tl35 bash run_tests.sh $G
$G --headless --path . res://scenes/viewport_harness.tscn -- --scenario=<name>
```

The new scenario `batch_035_profile_max_hp_flow` is registered in
`src/viewport_harness.gd` and `run_tests.ps1`.

## Log summary (after rebase onto e3efcad)

| Run | Result |
|---|---|
| Import | exit 0 |
| parse_gate / boot_gate | PASSED |
| Logic suite | **4834 passed, 0 failed** (adds `Batch035Checks`: 28 assertion sites) |
| `batch_035_profile_max_hp_flow` | **7/0** |
| `batch_034_aftermath_flow` | 10/0 |
| `batch_033_zero_hp_flow` | 70/0 |
| `batch_032_damage_responses_flow` | 33/0 |
| `batch_031_linked_damage_flow` | 25/0 |
| `shared_spell_flow` | 67/0 |
| `downed_area_damage_flow` | 2/1, pre-existing on `main` d823423 (unchanged) |
| `party_recovery_flow` | 17/2, pre-existing on `main` d823423 (unchanged) |

## Receipts (from logs)

- **Actual monster hit (`_execute_monster_attack`):** 6 damage dealt left the
  maximum at 34, under source `<goblin id>:b035:hollow`. The DTO is valid.
  The actual `advance_combat_turn` lowered it by 1 once. A completed Long Rest
  restored the maximum to 40 and left no sources.
- **Actual player attack command:** a control longsword against a
  slashing-immune target left HP at 500. With the scoped profile, the same
  command left HP at 492 (fire). The catalog longsword is still slashing.
- **Logic:**
  - Equivalent sources are owned separately and removed independently. The
    floor clamp records requested versus applied amounts and reverts exactly.
  - Increases do not stack on re-application and survive the removal of an
    equivalent source.
  - Aura protection refuses reductions.
  - Malformed rules and DTOs (6 + 4 cases) are refused, and a legacy DTO
    validates.
  - Profiles: first-source replacement, additive bonuses on the replaced
    ability, an unoffered type choice is ignored, condition gating, an
    unrelated weapon is inherited, an actual `resolve_weapon_attack` settles
    as `force`, and the school-scoped DC works with fixed + additive. Seven
    malformed-profile cases are refused.

## Limits

- **S-130:**
  - Only the monster-rider consumer and the API are wired. Class/spell/item
    acquisition of `max_hp_source` is not wired.
  - Maximum-zero death and remains are S-131, and the floor defaults to 1.
  - Injury-specific healing blocks are not modelled. Cure events are limited
    to rests and turn start.
  - Dictionary creatures have no maximum-HP sources.
  - The native `reduce_max_hp` rider is not migrated.
- **S-126:**
  - Weapons and spell save DCs only; spell attack bonus, range and components
    (S-140) are not covered.
  - The damage-type choice has no UI picker; without an answer the inherited
    type is kept.
  - A replaced die on a fixed-number stat-block formula prefixes the die.
  - Scope predicates are fixed fields (ids, properties, melee, schools,
    required condition), not general S-024 boolean expressions.
- There is no fresh-process relaunch probe; the save round trip is covered in
  logic.
- Independent review is still pending.

## Source manifest (sha256, first 16 hex)

| File | sha256/16 |
|---|---|
| src/characters/max_hp_source_rules.gd | 93be021d58b9664d |
| src/combat/attack_profile_rules.gd | dc889383707e5652 |
| src/batch_035_checks.gd | 9851e18fa1252e1b |
| src/batch_035_controls.gd | 258e693e2f4ef230 |
| data/fixtures/batch_035/classes/profile.json | d2388d084a8c4436 |
| data/fixtures/batch_035/monsters/drainer.json | e5a756a367050ecd |
| src/characters/character.gd | f9ffb7bc5b43a8a8 |
| src/characters/rest_rules.gd | 748b4c489a269467 |
| src/combat/combat_action.gd | 4b66d8d5d9502d11 |
| src/spells/spell_permission_rules.gd | 6a9b712991ebc413 |
| src/autoload/save_manager.gd | b34c28a35a11f84d |
| src/autoload/data_loader.gd | a1ab7d286ca34602 |

Also changed: `src/test_runner.gd`, `src/viewport_harness.gd`, `run_tests.ps1`.
