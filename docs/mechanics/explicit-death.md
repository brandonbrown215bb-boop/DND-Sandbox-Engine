# Explicit death or destruction without damage (S-119; PARTIAL)

Done means: "Explicit death or destruction without damage (S-119): living, already-zero and ineligible targets, with no duplicate remains or effects."

SRD 5.2.1 authority: Power Word Kill (p.154, "If the target has 100 Hit Points or fewer, it dies"); Instant Death (p.17). Death is settled directly, not simulated with a large damage number.

## Data
Shared-spell effect `{"type": "settle_death", "policy": {...}}`. Policy keys (all required, no engine defaults): `id`, `outcome` (death/destruction), `remains`, `gear` (retained/destroyed/destroyed_except_magic), `cause`, `at_zero` (`settle` or `refuse`), `eligibility` (object; `max_current_hp`, `creature_types`, `excluded_creature_types`). Unknown keys and `successor` are refused at load (`ZeroHpAftermathRules.explicit_policy_error`).

## Runtime
- Pre-cost: `SpellCastValidation` calls `ZeroHpAftermathRules.explicit_cast_error` before slot/Action payment; `_death_target` also finds downed players and dead monsters so they are refused or settled rather than treated as empty ground.
- Refused: objects/empty ground, already-dead targets (monster not alive or with aftermath; Character dead or with corpse_state), creature type not listed or excluded, HP above `max_current_hp`, and HP 0 when `at_zero` is `refuse`.
- `settle_explicit` rechecks eligibility at resolution (stale target → `applied: false`, nothing changes), then reuses the S-043/S-117 corpse/remains/gear/cause body shared with `settle` (`_apply`). Receipt: `explicit: true`, `was_at_zero`, `damage: 0`; cause_source has no damage_type. Monsters go through the normal defeat path; a downed Character dies once (death serial +1, no Death Save).

## Persistence
No new saved fields: corpse_state/cause_source as in S-043. Dict and JSON DTO, real save and a fresh process (`batch_073_explicit_death_reload`) keep one death; forged causes are refused; legacy corpses without cause_source load.

## Declared fallback (Batch 081)
Brandon's ruling (#45): "support a declared fallback, not an automatic one on every death effect. Power Word Kill deals 12d12 Psychic above 100 HP; other effects follow their own text. Support explicit object destruction separately from creature death, reusing the existing destruction handling."

- Optional policy key `fallback`: `{"when": "above_max_current_hp", "damage": <dice>, "damage_type": <type>}`. All three keys required; it needs `eligibility.max_current_hp`; plain integers, unknown `when` values and unknown damage types are refused at load. No policy gets a fallback unless it declares one.
- With a fallback, an over-limit creature is not refused before cost; at resolution it takes the rolled damage through `CombatAction.resolve_damage` (immunity/resistance/temp HP apply) and no death record is written. Everything else (dead targets, objects, type rules, `at_zero`) is still refused pre-cost.
- `power_word_kill` is now data (`execution: shared`, policy `power_word_kill`, limit 100, fallback 12d12 psychic; SRD p.154). The per-ID PWK branch in `SpellResolver`/`SpellHealingResolver` is gone.

## Object destruction (Batch 081)
Separate shared-spell effect `{"type": "destroy_object", "policy": {"id", "cause", "magical": "refuse"}}` (`ObjectDestructionRules`). Only unattended (not worn/carried), nonmagical, intact objects are eligible; creatures, magic objects and destroyed objects are refused pre-cost in `SpellCastValidation`. It sets the object's HP to 0 and records `destroyed_cause`/`destroyed_by_policy`/`destroyed_source`; the existing `CombatObjectRules.sync_resolution_target` → `settle_destruction` does the rest (spill, open, containment, tethers).

## PARTIAL
- `settle_death` still refuses objects; objects use `destroy_object`. `magical: "allow"` is refused (the combat object route only reaches nonmagical objects).
- No successor/replacement on explicit death.
- Only the `above_max_current_hp` fallback trigger exists.
- Native Disintegrate content not converted; multi-target not covered.
