# Containment, movement and legal release

S-170 provides admission and inspection for actual party Characters and room
objects, including loose objects carrying exact item copies. It does not turn
inventory compartments into creature containers.

An authored room object may declare `containment`. A species definition may
declare the same policy; Character initialization copies it to the actual
creature's `containment` field, which its DTO retains.

```json
"containment": {
  "capacity": 2,
  "occupant_kinds": ["character", "object"],
  "sizes": ["tiny", "small", "medium"],
  "creature_types": ["humanoid", "beast"]
}
```

`capacity` is a whole count from 1–32. Each admitted body consumes one place.
`occupant_kinds` and `sizes` must explicitly declare eligibility. Optional
`creature_types` restricts Character occupants. Unknown sizes refuse. This is
count capacity; it adds no inferred weight, volume, air or size-equivalent units.
A creature's carried/worn gear stays in its inventory, retains its exact copy
identities and ownership, and does not become a separately admitted body.
A loose room object's exact `contents` similarly stay on that object.

The room's **RoomContainment** controls select a container and an exact occupant.
**Admit occupant** offers confirmation and Cancel; **Inspect occupants** lists
capacity, exact occupants, gear identities and the container's external location.
Equal display names remain distinguishable by kind and stable ID. Confirmation
rechecks actual body instances, actor, room, declared eligibility, current count,
plane, altitude, geometry and reach. The actor and occupant must be within one
hex and five feet vertically of the external container, on its plane. An object
with an opening must be open and unlocked. Fixed objects cannot be occupants;
burning objects cannot be admitted or used as containers. Cancellation, actor
switching, teardown, replaced bodies, moved locations and newly full capacity
refuse without admitting anything. Admission adds one relationship and does not
charge an action or advance the clock.

`containment_occupants` is a room DTO array. Each row has `container_kind`,
`container_id`, `occupant_kind`, and `occupant_id`. Bodies are referenced rather
than copied. One body can have only one parent, and the graph must be acyclic.
Object identities are room-local; Character identities are campaign-wide.
A creature becoming downed after entry retains its exact relationship and gear;
restoration does not erase or readmit it. Admission still requires a living body.

`ContainmentRules.location()` reports an internal location with its exact parent
and no external coordinate. `external_location()` follows parents to the outer
container. A contained body's stored room position is its remembered entry cell;
it is neither drawn nor used to block that cell. The shared physical-location
query reports `location_kind: internal`, `location_known: false`, `position: null`
and a separate `external_location`. Located source-end capture uses that same
boundary instead of placing an internal effect at the entry cell.

The supported control host is persistent room exploration. While a room has
occupants, its controls expose admission, inspection and external Character
movement. Internal occupants cannot move independently. External creature
containers use ordinary movement; movable object containers use the existing
object-movement owner. External gear transfers to/from internal creatures and
encounter entry refuse. Shared room spells use the explicit target rules below.
External damage to an occupied object uses its normal defenses; destruction
requests legal release or deferred settlement.

Switching back to the room map at the existing exit does not move bodies.
Represented room travel carries groups rooted in travelling party Characters;
stationary object containers holding party bodies and dungeon exit still refuse.
An entrance-room fixture can use the existing entrance checkpoint without moving
or releasing its occupants. No new save point or mid-choice save is added.

Room DTO validation checks graph structure, actual object links and object
capacity/eligibility. SaveManager additionally checks Character links and their
declared policies, validates both party and player-only DTO representations, and
rejects duplicate global occupancy before replacing the session. Reload restores
the saved graph directly, without admission callbacks or inventory receipts.

S-172 supplies the movement and release contract below. S-167 connects actual
projected vessel passengers through [the vessel contract](projected-vessels.md).
Shared air and catalog conversions remain separate work. Neutral and renamed executable fixture data proves
this boundary; it does not certify a monster or magic-item conversion. The
[slice registry](../planning/vocabulary-slices.md#containment-occupancy) owns the
verification boundary.

## Authored internal harm, targeting and checks (S-171)

Optional fields extend the same `containment` policy on an actual room object
or Character. They do not name a spell, monster or item ID.

```json
"targeting": ["same_interior", "occupant_to_container", "external_to_occupant"],
"internal_damage": {"damage": "2d6", "damage_type": "acid", "interval_seconds": 6},
"escape": {"ability": "DEX", "dc": 15, "seconds": 6},
"rescue": {"ability": "STR", "dc": 15, "seconds": 6}
```

`internal_damage` uses the shared dice and typed-damage settlement, including
Character defenses, temporary HP, source cleanup and damage history; objects
use existing object defenses/thresholds. Each admission gets an exact source and
next-damage time. Campaign time consumes each due occurrence before applying
it. Repeating settlement at that time, opening controls and restoring a checkpoint
cannot replay it. The object/creature container supplies the damage source;
it is not the occupant or the rescuer. A container reduced to zero HP requests
release for its occupants instead of continuing its internal harm.

A spell or weapon also declares `containment_targeting`, using the same routes:

| Route | Source and target |
|---|---|
| `same_interior` | Two occupants of the exact same immediate container |
| `occupant_to_container` | Occupant affects its immediate container |
| `external_to_occupant` | Outside source affects the exact occupant |
| `occupant_to_external` | Occupant affects an outside target other than its container |

Both the container policy and effect must permit the route. Missing permissions
refuse before slot/source costs. Separate interiors and crossings through nested
boundaries refuse. Crossing effects currently use individual flat spell payloads;
ordered secondary targets, areas and placement effects refuse. External-only
spells keep their ordinary eligibility. Spatial recipient lists exclude contained
bodies, so an external area step cannot hit a remembered entry cell. Self effects
still obey their normal rules; room placement/projection/factory changes involving
containment remain unavailable. Range/plane checks use the separate external
container origin after eligibility passes, never the occupant's entry cell.

Room controls select an exact occupant, then **Escape containment** or **Rescue
occupant**. Escape rolls that occupant's declared STR (Athletics) or DEX
(Acrobatics) check; rescue rolls a distinct outside rescuer's check, within one
hex/five vertical feet on the same plane and represented passable geometry.
The container cannot rescue its own occupant. Rules, exact body/relationship
instances, locations, actor, room and control lifetime are rechecked at
confirmation. Cancellation, changed rules/geometry/identity, duplicate IDs,
incapacity and an already pending release refuse before any time is spent.
An actual failed or successful attempt consumes its authored seconds once.

Escape, rescue and object/creature container destruction call
`ContainmentRules.request_release()`. Authored release policies reserve and recheck legal destinations before release. Legacy policies without `release`, or blocked releases, report **settlement deferred** and store `release_pending` on the exact relationship. The original body, gear and parent relationship stay
intact; no body is placed at an invented location or deleted. A pending row
stops internal harm and further checks/costs. Repeated destruction preserves an
existing escape/rescue receipt rather than replacing its actor/reason.
Inspection displays the pending reason. Encounter transfer remains refused; container movement carries the pending relationship too.

New rows retain `source_id` and optional `next_damage_seconds`; the room retains
`containment_serial`. Save preflight rejects duplicate sources, malformed timers,
serials and pending receipts, including destroyed links lacking an explicit
pending release. Legacy four-field occupancy records remain valid. Both party
and player-only checkpoints restore the exact data directly; no roll, damage,
cost, admission or release callback runs during load. Active and deferred
checkpoints use the existing entrance save host, without adding mid-choice saves.


## Moving containers and legal release (S-172)

A policy can add an explicit release search and optional absolute campaign expiry:

```json
"release": {
  "range_hexes": 1,
  "fallback_range_hexes": 2,
  "no_space": "defer"
},
"expires_at_seconds": 600
```

Ranges are 1–24 hexes. The optional fallback range must include the primary
range. Each occupant gets the nearest legal destination in the primary range,
then the declared fallback range if needed; ties use coordinates. Missing
`release` preserves legacy deferred settlement. An expiry requires a release
policy and ends admission/check eligibility at that campaign deadline.

Release uses `PlacementRules` and `PhysicalFactsRules` for represented geometry,
plane, clearance and full body footprints. External bodies, room objects,
familiars, steeds and represented created actors reserve their space. Every
occupant in a batch reserves its own footprint, including loose gear objects.
A destruction or expiry reserves the entire immediate occupant group before
removing any relationship. If any destination fails, all remain inside.
Nested relationships remain attached to the released body; they are not flattened.

`no_space: refuse` refuses an escape/rescue attempt before rolling or paying its
seconds when no release can fit. `defer` permits the successful check and records
pending release without moving the body. Destruction and expiry cannot undo their
cause; either policy retains a blocked batch pending rather than deleting anyone.
The first receipt keeps its reason, actor, time and a copy of the authored release
policy. Repeated destruction/expiry cannot overwrite it or duplicate a release.

Escape/rescue confirmation captures the exact reserved destination and rechecks
it before roll/time. **Finish pending release** reserves all pending immediate
occupants of the selected container and confirms them together. Its confirmation
rechecks exact room/body instances, relationships, policy, external origin, body
size/plane and every destination before committing. Cancellation and retained or
stale callbacks cannot free a subset. A released body is placed on the destination
floor; its exact inventory/contents remain on that body. This adds no inventory
transfer, movement expenditure, damage roll or new checkpoint.

An external creature container uses `LocalRoomRules.move`, retaining ordinary
Speed, path, mode, terrain and time costs. Internal occupants keep their graph
and obtain their external location by following the moving parent. **Move
container** sends a movable object through `TetherRules.move_object_anchor`,
which rechecks exact identity and legal footprint; fixed/internal objects refuse.
The object movement owner retains its existing cost behavior.

Room-map travel transfers Character-rooted groups to an existing represented
tactical room, reserving legal arrivals for every external party body first.
It transfers the actual nested objects and rows, checks room capacity/object-ID
collisions and preserves source IDs and pending receipts. Internal remembered
coordinates are rebased into the destination; they remain internal locations.
An unrepresented destination or a stationary object containing a party member
refuses before travel time. Ordinary room travel still costs 60 seconds.
Encounter entry, dungeon exit while party containment is involved, general
planar travel and air supply retain their existing restrictions. Projected vessel
ground movement and endings use [S-167](projected-vessels.md); occupied vessels
still refuse room-map travel and vessels refuse encounter entry.

Full-party and player-only entrance checkpoints retain active expiry and pending
release state. Load restores it directly; controls resume release through a fresh
reservation. Validation uses the checkpoint's clock for expiry, never the current
session's time. It rejects malformed pending policies before replacing a session.
The [slice registry](../planning/vocabulary-slices.md#containment-movement-release)
owns the verified boundary.
