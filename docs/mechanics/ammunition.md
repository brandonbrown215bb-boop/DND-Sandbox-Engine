# Exact ammunition (S-249 / CXM-01)

The bounded host uses exact inventory copies, ordinary attack budgets and the
campaign clock. Catalog conversion is separate: native weapons without the new
declaration retain their existing behavior.

## Definitions

An ammunition weapon declares a nonempty `ammunition_kind` and the existing
`ammunition` property. A matching item has `type: "ammunition"` and the same
`ammunition_kind`. Kind names are data, not registered weapon or item IDs.
Every exact ammunition record is **one piece**. `purchase_quantity` describes a
shop lot; adding a copy does not expand it into that many pieces. This delivery
does not promote package or shop definitions or implement shop lot expansion.
`data/fixtures/ammunition/items.json` supplies renamed production-loader examples
for arrows, bolts, sling stones, firearm bullets, needles and their weapons.

## Shots

`AmmunitionRules` finds carried backpack pieces and direct contents of carried
containers, including equipped container hosts. It draws the first matching
backpack piece, then container contents in inventory order. The existing exact
container limits still measure individual pieces. Nested containers remain outside
the existing S-196 boundary.

Ordinary Attack checks ammunition and hands before payment or RNG, snapshots the
exact weapon identity before activation choices, rechecks it after a choice, then
detaches one piece at commitment. A Shield or a second occupied weapon hand
prevents loading. One-handed offhand profiles can load when the main hand is empty.
The other hand supports a two-handed weapon during the shot. Existing native
Loading limits the ordinary Attack action to one shot. Readied attacks check the
same eligibility before paying their Reaction. Shared `weapon_attack` casts check
ammunition before spell payment and after asynchronous choices; their nested
attack uses the same debit host.

A transient shot receipt binds actor, exact weapon and exact ammunition copy.
Captured attack continuations reuse that debit; misses also expend a piece.
The receipt never enters a loaded definition or checkpoint. Unfinished encounter
state is discarded on teardown; no combat checkpoint is added.

## Recovery

Combat completion forms one batch per actor: `spent_count`, completion clock,
site, and the first `floor(spent_count / 2)` exact spent copies. The rest are lost.
The Character Sheet offers **Recover ammunition (1 minute)** in exploration at
that site. The action restores one encounter batch to the backpack and advances
campaign time by exactly 60 seconds. Insufficient backpack space, wrong site,
combat or an Incapacitated/dead actor refuses before time or inventory mutation.
Elapsed time alone does not recover ammunition. Completing recovery removes the
batch, so later presses and reloads cannot replay it. Multiple batches require
separate recovery actions. The represented site is campaign, overworld hex, generated-room coordinate and
current dungeon/local-room identity; returning to the site can recover its retained batch.

Both existing full-party and player-only checkpoint DTOs save
`ammunition_recovery`; legacy DTOs default to an empty array. Preflight rejects
malformed/fractional counts, count/piece disagreement, future completion clocks,
invalid copies, duplicate ownership, reused inventory serials and disagreeing
player/party mirrors before session replacement. Retained copies participate in
the existing global ownership check alongside inventories and room contents.

## Boundary

This supplies the ammunition primitive and neutral loaded executable data. It
does not enable Crown catalogs, package grants, merchant purchase lots, monster
ammunition inventories or corrosion/destruction of fired ammunition. When the
latter consumer is wired it must exclude destroyed pieces before recovery.
No general liquids, S-237/S-238 completion, backgrounds or multiclass support is
required. Loot and bounty payment routes are unchanged.

Source: SRD 5.2.1 Ammunition/Loading, as retained in the equipment
[source-page extraction](../planning/preparation/crown-equipment/source-pages.json)
and [Arrow candidate](../planning/preparation/crown-equipment/items/arrows.json).

Production checks: `ammunition_flow` and its automatically paired
`ammunition_reload`, through the supported Windows runner. Raw logs remain in
ignored `.artifacts/tests/`.
