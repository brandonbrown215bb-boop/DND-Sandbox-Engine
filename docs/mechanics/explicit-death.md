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

## PARTIAL
- Objects cannot be destroyed by this effect (refused).
- No successor/replacement on explicit death.
- Power Word Kill's "otherwise 12d12 Psychic" fallback is not modelled; over-threshold targets are refused pre-cost.
- Native Disintegrate/Power Word Kill content not converted; multi-target not covered.
