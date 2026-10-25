# Batch 081 build: S-119 declared death fallback and object destruction (#45 follow-up)

- **Card:** Q-20261025-230738-c635
- **Stacked on:** `batch-080-last-charge-text` (PR #53, including reviewer commit 8dd8ba5)

## Ruling (Brandon, verbatim)
"support a declared fallback, not an automatic one on every death effect. Power Word Kill deals 12d12 Psychic above 100 HP; other effects follow their own text. Support explicit object destruction separately from creature death, reusing the existing destruction handling."

SRD 5.2.1 p.154, Power Word Kill: "If the target has 100 Hit Points or fewer, it dies. Otherwise, it takes 12d12 Psychic damage." (no creature-type exclusions)

## Done means
- PWK at 100 HP or fewer kills; above 100 HP deals 12d12 Psychic and records no death.
- A death effect without a declared fallback gets none (still refused before cost).
- Object destruction targets an object and goes through the existing `settle_destruction` handling.
- Refusals happen before any slot or Action is paid; save/load and a fresh process keep the results.

## What changed
- `ZeroHpAftermathRules`: optional policy `fallback` `{when: above_max_current_hp, damage: <dice>, damage_type}` validated at load (`fallback_error`); `fallback_applies`; the HP-limit refusal is skipped only when a fallback is declared; `settle_explicit` rolls the fallback through `CombatAction.resolve_damage` and returns `{applied: false, fallback: true, damage, rolled, damage_type, policy_id}`.
- `SharedSpell`: `settle_death` reports `killed`/fallback damage; new `destroy_object` effect.
- New `ObjectDestructionRules` (policy `id`, `cause`, `magical: refuse`): refuses creatures, worn/carried, magical and already-destroyed objects; `destroy` sets HP 0 and records the cause, then the existing `CombatObjectRules.sync_resolution_target` → `settle_destruction` runs.
- `SpellCastValidation`: pre-cost `destroy_object` refusal.
- `power_word_kill` data: `execution: shared`, `settle_death` policy with limit 100 and the 12d12 psychic fallback. Per-ID PWK code removed from `SpellResolver`/`SpellHealingResolver` (ADR-0018). Words of Creation (two targets) still passes in `bard_action_flow`.
- Fixture `fixture:b081_unmake_object`; docs `mechanics/explicit-death.md`, `planning/vocabulary-slices.md`.

## Verification (Godot 4.7.2, import x2, sequential)
- Logic suite: **6316 passed, 0 failed** (Batch081Checks: validation mutations, 100/101/150 HP, psychic immunity, temp HP, character death without Death Saves, no-fallback refusal, objects, DTO and legacy corpse).
- Scenarios: `batch_081_declared_fallback_flow` PASS, `batch_081_declared_fallback_reload` PASS, `batch_073_explicit_death_flow` PASS, `batch_073_explicit_death_reload` PASS. `bard_action_flow`: only the pre-existing Prone failure seen on main ("The healed Prone recipient can decline standing"); Words of Creation kill assertions pass.
- No SCRIPT/Parse/Compile errors in any log.

## PARTIAL
- `destroy_object` with `magical: "allow"` is refused (the combat object route only reaches nonmagical, unattended objects).
- Only the `above_max_current_hp` fallback trigger exists.
- No successor on explicit death; native Disintegrate not converted.
