# Projected vessel cargo, passengers and endings

S-167 extends `ItemProjectionRules`, exact `ContainerRules` compartments, room
containment records and `LocalRoomRules.move`. It adds no replacement inventory
or passenger pool. A new item definition using this syntax needs no ID branch.

An item's `actor_projection` may add:

```json
"vessel": {
  "containment": {
    "capacity": 3,
    "occupant_kinds": ["character", "object"],
    "sizes": ["tiny", "small", "medium"],
    "release": {"range_hexes": 2, "fallback_range_hexes": 3, "no_space": "defer"}
  },
  "on_reversion": {"cargo": "retain", "passengers": "release"},
  "on_dismissal": {"cargo": "release", "passengers": "release"},
  "on_destruction": {"cargo": "release", "passengers": "release"}
}
```

All four fields and both decisions in each ending policy are required. The
existing explicit `reversion` policy still determines original-copy HP,
overflow, destruction and bag/ground return. `zero_hp` or destruction of the
original selects `on_destruction`; the explicit **Revert** control selects
`on_reversion`; **Dismiss** selects `on_dismissal`. Both voluntary controls use
the existing `dismiss_cost`, paid only on successful settlement.

Cargo uses the item's existing `container.compartments`. Actual child copies
remain in the original copy's `state.contents`, including their instance IDs,
charges and other state. **Stow cargo** selects an exact backpack copy and, when
two or more compartments accept it, the exact compartment; **Take out cargo**
offers the exact held child when two or more are held (batch 068, see
[exact contents and parts](exact-contents-and-parts.md)). They reuse normal capacity checks and six-second transfer
costs. Projected cargo transfers require the outside owner within one hex/five
vertical feet, on the vessel's plane, in its actual current room. Remembered
coordinates in another room give no access. Internal occupants cannot transfer
external cargo. A blocked/dead vessel refuses new cargo transfers.

Passengers are actual Characters or objects in `containment_occupants`, whose
parent is the projected actor's exact ID. Their own inventories/contents stay
on their bodies. Admission, inspection and legal disembarkation use the existing
[containment controls](containment.md). Projected vessels can be containers;
they cannot themselves be admitted as occupants.

**Move container** on an owned vessel selects a destination through the shared
room movement owner. It checks Speed, path, surfaces, plane, clearance and the
full vessel footprint at each traversed cell, spends the normal six seconds,
and updates `created_actor_positions`. Cargo remains in that exact vessel's
original record; passengers obtain their external location through the moving
parent. They cannot independently walk from their remembered entry cells.
Movement effects apply to the vessel body, not its owner.

Each ending reserves every required passenger and cargo release plus any ground
return of the original before moving anything. Passengers use containment's
legal release/fallback search. Cargo becomes loose room objects carrying those
same exact child records; its actual physical size, including saved overrides,
determines each footprint. Ground return also reserves the original's actual
physical size. Existing empty pickup records can be reused. Aliased ground
object IDs refuse the complete ending before any copy can overwrite another;
the cargo remains available to unload normally. Room capacity counts only new
objects and does not block a bag return that needs no ground object.

`retain` cargo stays inside the original copy when it returns. A policy that
can destroy the original must declare cargo release for that ending. Passengers
may be retained only on a surviving original with `destination: ground`; the
existing rows then point to that exact ground object, with the declared
containment policy. An occupied ground copy cannot be picked up. Destruction
must release passengers. Creatures are never stored as inventory children.

A blocked voluntary ending leaves the living form and all contents unchanged,
without paying its cost. Destruction settles HP/overflow once and retains the
original, cargo, body anchor and passenger links until the complete ending can
fit. Containment ticking cannot independently complete that destruction behind
the projection's back. An explicit passenger disembarkation still uses normal
containment release. Repeated damage, stale activation serials and repeated
ending callbacks cannot repeat cargo release or original destruction.

Existing entrance checkpoints retain active forms and blocked lethal endings.
Both full-party and player-only DTO paths validate exact projection identities,
cargo, links, pending placement and the one actual room origin before replacing
the session. Validation uses isolated actor caches; checking even a refused
save cannot replace or heal a live vessel. Reload restores data without invoking
admission, projection, release or cost callbacks. No new checkpoint is added.

The delivered host is persistent-room ground movement and endings. Occupied
vessels refuse room-map travel; vessel encounter entry refuses, and empty or
cargo-only vessels left behind stay in their actual room. Waterborne propulsion,
general travel, air supply and real catalog conversion remain separate. Neutral
and renamed fixtures establish the runtime contract; a complete source-backed
consumer is still required before converting a real vessel item.

The [slice registry](../planning/vocabulary-slices.md#projected-vessel-contents)
owns the verified boundary and production checks.
