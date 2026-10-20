# Batch 034 build: zero-HP aftermath (S-093, then S-119)

Built 2026-10-20 by Runtime Builder on branch `batch-034-s093-s119` (base
`main` @ `d823423`). **Build evidence only.** This is not acceptance: slice
counts, VS numbers and the checkpoint are unchanged until independent review
and owner acceptance.

## Scope implemented

Both slices are one shared module, `src/combat/zero_hp_aftermath_rules.gd`
(`ZeroHpAftermathRules`), per ADR-0018. JSON declares the behavior. No content
ID is branched on. Changes to existing consumers are small and neutral.

### S-093: no-roll Death Save outcome or cancellation (deps S-092, S-117)

- New Character feature type `death_save_outcome` with these fields:
  `source_instance_id`, `outcome` (`success|failure|stabilize|cancel`),
  `roll: false`, optional `required_condition`, and optional `min_failures` /
  `max_failures` (0–2). Class loading validates it (`DataLoader`
  `_sanitize_class_features`). A malformed rule is refused.
- `Character.make_death_save` takes the first eligible rule before any d20,
  bonus, Indomitable, Stroke of Luck, Bardic Inspiration or roll-token step.
  `cancel` changes no counter. `success` and `failure` move one counter and
  reuse the existing third-success stabilization and third-failure
  `death_saves` death. `stabilize` reuses `stabilize()`.
- `CombatState._start_combat_turn` checks for a pending automatic rule before
  any Stroke of Luck, Bardic Inspiration or roll-token prompt. When one applies,
  it offers no bonus choice, logs the outcome and stores
  `last_automatic_death_save`.
- The rule is stateless and no save field was added, so legacy saves load
  unchanged.

### S-119: instant death or destruction distinct from ordinary HP loss (deps S-117, S-032)

- New damage-source policy `zero_hp_aftermath`: `{id, trigger:
  "reduced_to_zero", outcome: death|destruction, remains: CorpseRules.REMAINS,
  gear: retained|destroyed|destroyed_except_magic, cause,
  precedes_zero_hp_replacement?, excluded_creature_types?}`. Destruction must
  use `destroyed` remains, and death cannot. Validation runs in
  `DataLoader._validate_semantics` for any content, including each monster
  attack. `zero_hp_aftermath` is added to the shared-spell field allowlist.
- Neutral carriers: a shared spell top-level field (`SpellResolver` copies it
  into the cast decisions) and weapon or monster attack data
  (`resolve_weapon_attack` copies it into the weapon damage decisions).
- `CombatAction.resolve_damage` settles it once, after ordinary HP
  settlement. It applies only when a living target went from above 0 HP to
  0 HP. The receipt keeps ordinary `hp_loss` and adds a separate
  `zero_hp_aftermath` receipt, which shared-spell damage receipts also carry.
- Characters keep the same actor. `CorpseRules.mark_dead` is used with the
  declared remains, and `corpse_state.cause_source` records the policy,
  outcome, source instance, actor, damage type and gear policy. A massive-damage
  death in the same occurrence takes the declared cause without a second death
  serial. The gear policy destroys exact item copies through
  `Inventory.destroy_instance`. `destroyed_except_magic` keeps items whose
  definition is `magical` or has a `rarity`.
- Dictionary creatures are set dead and get a `zero_hp_aftermath` record.
- Precedence: `precedes_zero_hp_replacement: true` bypasses the shared S-117
  replacement and the Relentless Rage fallback. Otherwise a successful
  replacement keeps the target above 0 HP and no aftermath applies. Native
  Death Ward still comes first.
- Revival: existing `CorpseRules.target_error` already refuses `dust` and
  `destroyed` remains. `CorpseRules.saved_error` validates the optional
  `cause_source` (keys, outcome, gear, and that destruction matches destroyed
  remains). Legacy corpses without it still load.

## Fixtures (bounded, production loader)

- `data/fixtures/batch_034/classes/vigil.json`: neutral class with two
  `death_save_outcome` rules (cancel while blessed; success while shielded with
  at least one failure).
- `data/fixtures/batch_034/spells/aftermath.json`: `dust` (death/dust/
  destroyed_except_magic, precedes replacement), `erase` (destruction, gear
  retained), and a `plain` control with no policy.
- `data/fixtures/batch_034/monsters/render.json`: an attack carrying a death
  policy that excludes constructs.

No catalog content was rewritten, and `tools/content_editor/` is untouched.

## Commands (Linux box, Godot 4.7.2-stable)

```bash
G=/workspace/godot/Godot_v4.7.2-stable_linux.x86_64
$G --headless --path . --import
git checkout -- docs/reviews/*.translation
TEST_SUITE=logic TEST_LOG_DIR=/tmp/tlogs bash run_tests.sh $G
$G --headless --path . res://scenes/viewport_harness.tscn -- --scenario=<name>
```

New scenario `batch_034_aftermath_flow` is registered in
`src/viewport_harness.gd` and in the `run_tests.ps1` integration list.

## Log summary

| Run | Result |
|---|---|
| Import | exit 0 |
| parse_gate / boot_gate | PASSED |
| Logic suite (all groups) | **4790 passed, 0 failed** (adds `Batch034Checks`: 25 assertion sites, about 38 executed) |
| `batch_034_aftermath_flow` | **10/0**, 0 script errors |
| `batch_033_zero_hp_flow` | 70/0, including the fresh-relaunch child |
| `batch_032_damage_responses_flow` | 33/0 |
| `batch_031_linked_damage_flow` | 25/0 |
| `shared_spell_flow` | 67/0 |
| `downed_area_damage_flow` | 2/1: **fails identically on unmodified `main` d823423** (Fireball third-failure assertion) |
| `party_recovery_flow` | 17/2: **fails identically on unmodified `main` d823423** (Cure Wounds / corpse-selection assertions) |

The two existing failures were reproduced in a clean `main` worktree on the
same box. Batch 034 did not introduce them, and they are not repaired here.

## Receipts (from logs)

- The actual `dust` cast on a party member gives a spell receipt with
  `hp_loss: 20` and `zero_hp_aftermath.applied`. The corpse records
  `remains: dust` and `cause: dust_aftermath`, and its `cause_source`
  `source_instance_id` starts with `spell:fixture:b034_dust`. Only the magic
  ring is kept. Revivify is refused, and the corpse DTO validates.
- The `plain` control leaves the target downed, not dead, with an empty
  aftermath.
- At the actual turn start, a downed actor with the cancel rule gets
  `last_automatic_death_save = {rolled:false, canceled:true}`. Failures stay
  at 1 and successes at 0.
- `erase` on the live goblin sets it dead with `remains: destroyed`.
- Logic: automatic outcomes roll zero d20s (counted from `Dice.dice_rolled`
  with 20 sides). Third success stabilizes; the existing d4 stable-recovery
  clock still rolls. Third failure gives a `death_saves` death. The policy
  bypasses or yields to S-117 Cinder replacement as declared. The monster
  attack consumer works, the construct exclusion works, and malformed
  policies, rules and saved cause details are refused.

## Limits

- S-093 covers only the Death Save host. Automatic outcomes for other saves
  and attacks, and the concentration and S-226 choices, are not covered.
  Rules are stateless, so per-occurrence use limits are not represented.
- S-119 has only the `reduced_to_zero` trigger. HP-threshold instant death with
  no damage (Power Word Kill style), death while already at 0 HP, and dropped
  gear with world placement are not represented. `dropped` is refused.
- Successors, hazards and remains objects (S-120) and revival-eligibility
  queries beyond the existing Revivify refusal (S-175) are not covered.
- Dictionary-creature aftermath records stay encounter-local, the same as
  existing Dictionary state.
- Character creature-type exclusion reads `feature_uses.creature_type` and
  falls back to `humanoid`.
- The native `disintegrate_on_zero` spell path is unchanged. It is not migrated
  onto the new policy.
- There is no fresh-process relaunch probe for 034. Save validation and
  round-trip are covered in logic through `to_dict`/`from_dict`.
- No independent review yet. The Quest Board was not claimed or moved; the
  builder was told to stay local.

## Source manifest (sha256, first 16 hex)

| File | sha256/16 |
|---|---|
| src/combat/zero_hp_aftermath_rules.gd (new) | 60d3979b97c02059 |
| src/batch_034_checks.gd (new) | 39b742cf45b013b6 |
| src/batch_034_controls.gd (new) | 8004b00847825a91 |
| data/fixtures/batch_034/classes/vigil.json (new) | 9211346e4d67eef4 |
| data/fixtures/batch_034/monsters/render.json (new) | 3874aef9749f3e97 |
| data/fixtures/batch_034/spells/aftermath.json (new) | c0f019cdec5d25be |
| src/characters/character.gd | 84d9f08e1cc32cdc |
| src/combat/combat_action.gd | 4a2ae2447ceb23b2 |
| src/combat/combat_state.gd | 69d8038aaa184d18 |
| src/combat/shared_step_executor.gd | ba4161a587d74e0b |
| src/characters/corpse_rules.gd | e27840c71e7c42cd |
| src/autoload/data_loader.gd | e6d2681dc47179fb |
| src/spells/shared_spell.gd | b639731bd99cc4e6 |
| src/spells/spell_damage_rolls.gd | c823b308c37273c4 |
| src/spells/spell_resolver.gd | 59e8e1b540411d3a |

Also changed: `src/test_runner.gd`, `src/viewport_harness.gd`, `run_tests.ps1`,
and `docs/planning/runtime-editor-parallel-pipelines.md` (owner decision
2026-10-20: the Runtime Builder and Runtime Reviewer bots replace Luna).
