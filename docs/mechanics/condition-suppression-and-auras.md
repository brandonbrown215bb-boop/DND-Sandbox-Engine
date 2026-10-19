# Condition suppression and combat auras

`condition_immunity_aura` suppresses its named condition for eligible Character
recipients while its bearer is active and within range. Suppression leaves the
condition and its original source/duration on the recipient. The condition clock
continues to tick; leaving range, losing the bearer or incapacitating the bearer
immediately makes the condition effective again only if it is still present.

The effect may declare its own `radius_feet` in 5-foot steps from 5 to 150. If
omitted, `aura_id` must match a `saving_throw_aura` on the same Character, whose
radius supplies the range. Matching `aura_radius_expansion` effects extend either
radius. Example neutral syntax:

```json
{
  "type": "condition_immunity_aura",
  "aura_id": "steady_courage",
  "condition": "frightened",
  "radius_feet": 10
}
```

The live combat projection records source-owner, bearer and recipient
Character IDs and their current distance. In this host the aura's owner also
bears it; the recipient is a separate Character. Every position refresh recomputes
membership from current player-entity positions. Multiple bearers suppress
independently: removing or moving one leaves another intact. These memberships
are encounter-local derived state; they do not alter saves or reacquire timed
conditions.

The bounded host is combat `Character` entities in the shared party projection.
Supported conditions are Blinded, Charmed, Deafened, Frightened, Paralyzed,
Petrified, Poisoned and Stunned. This accepted suppression contract does not add exploration or monster feature
auras. Batch 027 adds separately authored [chosen protections and timed entry
benefits](temporary-hp-and-entry-protections.md), pending independent acceptance;
condition suppression itself still ends with membership.
