# ADR-0008: Combat light markers and modeled visibility

Status: Accepted; amended 2026-10-07 and reconciled 2026-10-09

## Decision and reason

Light spells need observable behavior on the tactical grid. Use temporary
source-owned markers for the current combat representation. `DancingLightsRules`
owns linked-light range/movement; `LightRules` owns its marker. CombatState
coordinates per-caster lifetime, recast, movement and dismissal.

The original visual-only rule is superseded by the Wave 2 visibility path.
`CombatPerception` now uses authored ambient illumination, actual light and
carried-copy radii, creature senses and wall LOS. Natural light is evaluated
at the target; intervening natural darkness does not obscure an illuminated
target. Magical Darkness retains its separate sense restrictions. Special
senses do not bypass walls. Sight-required spells and Counterspell require
visibility; attacks against known unseen targets use the modeled penalties.
Darkness removes overlapping Light whether cast first or second.

## Current limits and migration

Light still uses the caster's hex as a touched-object stand-in. Arbitrary
object attachment/covering, hostile held-object saves, cover, dropped-light
placement, ordinary NPC senses and remote sensors are not certified.
Combat markers and transient visibility bindings are not saved. Carried
Torch/Lantern copies have their separate durable fuel/identity path.

Preserve these source/visibility guarantees during migration. Under
[ADR-0018](0018-shared-data-driven-rules-runtime.md), spell policy belongs in
data; current named marker helpers are implementation owners, not the final
extension mechanism. Expanding the modeled world requires explicit acceptance,
not a full-lighting claim inferred from the existence of a marker.
